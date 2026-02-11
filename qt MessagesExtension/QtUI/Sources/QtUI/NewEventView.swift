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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("New event").font(.title)
                TextField("Name your event...", text: $eventName).padding(8).frame(maxWidth: .infinity, maxHeight: 48).border(.placeholder  )
                
                
                Text("What times might work?").font(.title2)
                HStack() {
                    DatePicker(selection: $startDate,   displayedComponents: [.hourAndMinute]) {EmptyView()}.labelsHidden()
                    Text("to")
                    DatePicker(selection: $endDate, displayedComponents: [.hourAndMinute]) {EmptyView()}.labelsHidden()
                }

                Text("What dates might work?").font(.title2)
                ZStack {
                    Rectangle()
                        .fill(.white)
                        .border(.placeholder)
                    MultiDatePicker(selection: $selectedDates) { EmptyView() }
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            }
            .padding()
            
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
                actions.requestCompact() // optional: collapse after inserting
            }
            .buttonStyle(.glassProminent)
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

#Preview {
    NewEventView()
}
