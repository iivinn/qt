//
//  NewEventView.swift
//  QtUI
//
//  Created by ivin on 2/11/26.
//

import SwiftUI

struct NewEventView: View {
    @Environment(\.messagesActions) private var actions
    
    @State private var eventName: String = ""
    @State private var startDate: Date = {
        today(atHour: 9)
    }()
    @State private var endDate: Date = {
        today(atHour: 17)
    }()
    @State private var selectedDates: Set<DateComponents> = []

    private var canCreateEvent: Bool {
        let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !selectedDates.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("🗓️ New Event").font(.title).fontWeight(.semibold)
                TextField("Name your event...", text: $eventName).padding(8).frame(maxWidth: .infinity, maxHeight: 48)
                    .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray.opacity(0.3), lineWidth: 2)
                    ).padding(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                
                Text("What times might work?").font(.title2)
                HStack(spacing: 8) {
                    HourWheelPicker(
                        hour: Binding(
                            get: { hourComponent(from: startDate) },
                            set: { startDate = dateWithHour(startDate, hour: $0) }
                        )
                    )
                    Text("to")
                    HourWheelPicker(
                        hour: Binding(
                            get: { hourComponent(from: endDate) },
                            set: { endDate = dateWithHour(endDate, hour: $0) }
                        )
                    )
                }

                Text("What dates might work?").font(.title2)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .stroke(.gray.opacity(0.3), lineWidth: 2)
                    MultiDatePicker(selection: $selectedDates) { EmptyView() }.frame(maxHeight: 340)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Button("Create event") {
                    // Basic validation
                    let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !selectedDates.isEmpty else { return }
                    guard endDate > startDate else { return }

                    guard let url = makeEventURL(
                        name: trimmed,
                        start: startDate,
                        end: endDate,
                        selectedDates: selectedDates
                    ) else { return }

                    actions.insertEventLink(url, trimmed.isEmpty ? "New Event" : trimmed)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .disabled(!canCreateEvent)
            }
            .padding(.all)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white).shadow(radius: 8))
            .padding(16)
            

        }
    }
}

private func makeEventURL(
    name: String,
    start: Date,
    end: Date,
    selectedDates: Set<DateComponents>
) -> URL? {
    var comps = URLComponents()
    comps.scheme = "qt"
    comps.host = "event"

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    // Encode dates as YYYY-MM-DD (keeps it short)
    let ymd = selectedDates
        .compactMap { dc -> String? in
            guard let y = dc.year, let m = dc.month, let d = dc.day else { return nil }
            return String(format: "%04d-%02d-%02d", y, m, d)
        }
        .sorted()
        .joined(separator: ",")

    comps.queryItems = [
        .init(name: "name", value: name.isEmpty ? "New Event" : name),
        .init(name: "start", value: iso.string(from: start)),
        .init(name: "end", value: iso.string(from: end)),
        .init(name: "dates", value: ymd)
    ]

    return comps.url
}

private func today(atHour hour: Int, minute: Int = 0) -> Date {
    let cal = Calendar.current
    let now = Date()
    var comps = cal.dateComponents([.year, .month, .day], from: now)
    comps.hour = hour
    comps.minute = minute
    return cal.date(from: comps) ?? now
}

private func hourComponent(from date: Date) -> Int {
    let cal = Calendar.current
    return cal.component(.hour, from: date)
}

private func dateWithHour(_ date: Date, hour: Int) -> Date {
    let cal = Calendar.current
    return cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
}

private func hourLabel(_ hour: Int) -> String {
    switch hour {
    case 0: return "12 AM"
    case 1...11: return "\(hour) AM"
    case 12: return "12 PM"
    default: return "\(hour - 12) PM"
    }
}

private struct HourWheelPicker: View {
    @Binding var hour: Int

    var body: some View {
        Picker("", selection: $hour) {
            ForEach(0..<24, id: \.self) { value in
                Text(hourLabel(value)).tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity, maxHeight: 96)
        .clipped()
    }
}

#Preview {
    NewEventView()
}
