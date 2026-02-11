//
//  RootView.swift
//  qt
//
//  Created by ivin on 2/10/26.
//

import SwiftUI

public struct ContentView: View {
    @State private var eventName: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var selectedDates: Set<DateComponents> = []
    @State private var showValidationAlert: Bool = false

    public init () {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Event name input
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Name your event...", text: $eventName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Start and end time selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What times might work?")
                            .font(.headline)
                        DatePicker("Start", selection: $startDate, displayedComponents: [.hourAndMinute])
                        DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.hourAndMinute])
                    }

                    // Calendar for selecting specific days
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What dates might work?")
                            .font(.headline)
                        if #available(iOS 16.0, *) {
                            MultiDatePicker("", selection: $selectedDates)
                                .labelsHidden()
                        } else {
                            Text("Calendar selection requires iOS 16 or later.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Create Event button
                    Button {
                        createEvent()
                    } label: {
                        Text("Create Event")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!isFormValid)
                }
                .padding()
            }
            .navigationTitle("New Event")
            .alert("Please complete the form", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }

    private var isFormValid: Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate && (!selectedDates.isEmpty || Calendar.current.isDate(startDate, inSameDayAs: endDate))
    }

    private var validationMessage: String {
        if eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Event name is required." }
        if endDate < startDate { return "End time must be after start time." }
        return "Please select at least one day or ensure your start and end are on the same day."
    }

    private func createEvent() {
        guard isFormValid else {
            showValidationAlert = true
            return
        }
        // TODO: Persist or send the event data where it needs to go
        // Example: print or log for now
        let days = selectedDates.map { $0 }
        print("Creating event:", eventName, startDate, endDate, days)
    }
}

#Preview {
    ContentView()
}

