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
    @State private var validationMessage: String?
    @State private var validationTask: Task<Void, Never>?

    private var normalizedSelectedDates: Set<DateComponents> {
        normalizeSelectedDateComponents(selectedDates)
    }

    private var selectedDatesBinding: Binding<Set<DateComponents>> {
        Binding(
            get: { normalizedSelectedDates },
            set: { selectedDates = normalizeSelectedDateComponents($0) }
        )
    }

    private var canCreateEvent: Bool {
        let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !normalizedSelectedDates.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("🗓️ New Event").font(.headline).fontWeight(.semibold)
                TextField("Name your event...", text: $eventName).padding(8).frame(maxWidth: .infinity, maxHeight: 48)
                    .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray.opacity(0.3), lineWidth: 2)
                    ).padding(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                
                Text("What times might work?").font(.subheadline).fontWeight(.medium)
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

                Text("What dates might work?").font(.subheadline).fontWeight(.medium)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .stroke(.gray.opacity(0.3), lineWidth: 2)
                    MultiDatePicker(selection: selectedDatesBinding) { EmptyView() }.frame(maxHeight: 340)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Button("Create event") {
                    // Basic validation
                    let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let canonicalDates = normalizedSelectedDates
                    guard !canonicalDates.isEmpty else { return }
                    if startDate >= endDate {
                        showValidation("Start time must be before end time.")
                        return
                    }

                    if hasDatesBeforeToday(canonicalDates) {
                        showValidation("Selected dates cannot be before today.")
                        return
                    }

                    if hasAlreadyPassedDateTime(canonicalDates, startDate: startDate) {
                        showValidation("Selected date and time cannot already be in the past.")
                        return
                    }

                    guard let url = makeEventURL(
                        name: trimmed,
                        start: startDate,
                        end: endDate,
                        selectedDates: canonicalDates
                    ) else { return }

                    validationMessage = nil
                    selectedDates = canonicalDates
                    actions.insertEventLink(url, trimmed.isEmpty ? "New Event" : trimmed)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .disabled(!canCreateEvent)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }
            .padding(.all)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(radius: 8))
            .padding(16)
            

        }
    }

    private func showValidation(_ text: String) {
        validationTask?.cancel()
        validationMessage = text
        validationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.2)) {
                    validationMessage = nil
                }
            }
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

private func hasDatesBeforeToday(_ selectedDates: Set<DateComponents>) -> Bool {
    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: Date())
    return selectedDates.contains { dc in
        guard let date = cal.date(from: dc) else { return false }
        return cal.startOfDay(for: date) < todayStart
    }
}

private func hasAlreadyPassedDateTime(_ selectedDates: Set<DateComponents>, startDate: Date) -> Bool {
    let cal = Calendar.current
    let now = Date()
    let startHour = cal.component(.hour, from: startDate)
    let startMinute = cal.component(.minute, from: startDate)

    return selectedDates.contains { dc in
        guard let day = cal.date(from: dc) else { return false }
        let startOnDay = cal.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day) ?? day
        return startOnDay <= now
    }
}

private func normalizeSelectedDateComponents(_ selectedDates: Set<DateComponents>) -> Set<DateComponents> {
    let calendar = Calendar.current
    return Set(selectedDates.compactMap { normalizeDayComponent($0, calendar: calendar) })
}

private func normalizeDayComponent(_ dateComponents: DateComponents, calendar: Calendar) -> DateComponents? {
    if let year = dateComponents.year,
       let month = dateComponents.month,
       let day = dateComponents.day {
        return DateComponents(year: year, month: month, day: day)
    }

    guard let date = dateComponents.date ?? calendar.date(from: dateComponents) else { return nil }
    let dayStart = calendar.startOfDay(for: date)
    let normalized = calendar.dateComponents([.year, .month, .day], from: dayStart)
    return DateComponents(year: normalized.year, month: normalized.month, day: normalized.day)
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
