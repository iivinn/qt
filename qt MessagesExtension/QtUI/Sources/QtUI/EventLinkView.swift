import SwiftUI

struct EventLinkView: View {
    @Environment(\.messagesActions) private var actions

    private let config: EventGridConfig
    @State private var mode: AvailabilityMode = .add
    @State private var selectedSlots: Set<SlotSelection> = []
    @State private var dragMode: DragMode?
    @State private var dragAnchor: SlotSelection?
    @State private var dragBaseSelection: Set<SlotSelection> = []
    @State private var inspectedSlot: SlotSelection?

    init(eventURL: URL? = nil) {
        self.config = EventGridConfig(url: eventURL)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("📅 " + config.name)
                    .font(.headline.weight(.semibold))
                Text(mode == .add ? "Tap or drag to mark your availability" : "Tap a box to see who is available")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    modeButton(title: "View availability", target: .view)
                    modeButton(title: "Add availability", target: .add)
                    Spacer(minLength: 0)
                    clearSelectionButton
                }

                if mode == .view {
                    tooltipView
                }

                GeometryReader { geo in
                    let layout = GridLayout(size: geo.size, columnCount: config.dates.count, rowCount: config.slotMinutes.count)
                    if mode == .add {
                        gridContent(layout: layout)
                            .contentShape(Rectangle())
                            .simultaneousGesture(dragGesture(layout: layout))
                    } else {
                        gridContent(layout: layout)
                            .contentShape(Rectangle())
                    }
                }
                .frame(height: 480)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

                Button("Submit availability") {
                    submitAvailability()
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .disabled(mode == .view || selectedSlots.isEmpty)
            }
            .padding(.all)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(radius: 8))
            .padding(16)
        }
    }

    private func modeButton(title: String, target: AvailabilityMode) -> some View {
        Button(title) {
            mode = target
            if target == .add {
                inspectedSlot = nil
            }
        }
        .font(.subheadline.weight(.medium))
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .foregroundStyle(mode == target ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(mode == target ? Color.black : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(mode == target ? Color.black : Color.gray.opacity(0.45), lineWidth: 1)
        )
    }

    private var clearSelectionButton: some View {
        Button {
            selectedSlots.removeAll()
            inspectedSlot = nil
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.medium))
                .frame(width: 16, height: 16, alignment: .center)
        }
        .frame(width: 36, height: 34, alignment: .center)
        .foregroundStyle(selectedSlots.isEmpty ? Color.secondary : Color.red)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedSlots.isEmpty ? Color.gray.opacity(0.35) : Color.red.opacity(0.75), lineWidth: 1)
        )
        .disabled(selectedSlots.isEmpty)
    }

    @ViewBuilder
    private var tooltipView: some View {
        if let inspectedSlot {
            let people = config.peopleAvailable(dayIndex: inspectedSlot.dayIndex, slotIndex: inspectedSlot.slotIndex)
            VStack(alignment: .leading, spacing: 4) {
                Text(config.tooltipTitle(for: inspectedSlot))
                    .font(.caption.weight(.semibold))
                if people.isEmpty {
                    Text("No one available yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(people.joined(separator: ", "))
                        .font(.caption)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
    }

    private func gridContent(layout: GridLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            headerRow(layout: layout)

            ForEach(config.slotMinutes.indices, id: \.self) { row in
                HStack(spacing: layout.spacing) {
                    timeLabel(for: row, layout: layout)
                        .frame(width: layout.labelWidth, height: layout.rowHeight, alignment: .trailing)
                    Color.clear.frame(width: layout.labelGap, height: layout.rowHeight)

                    ForEach(config.dates.indices, id: \.self) { dayIndex in
                        slotCell(dayIndex: dayIndex, row: row)
                            .frame(width: layout.columnWidth, height: layout.rowHeight)
                    }
                }
            }
        }
    }

    private func headerRow(layout: GridLayout) -> some View {
        HStack(spacing: layout.spacing) {
            Color.clear
                .frame(width: layout.labelWidth, height: layout.headerHeight)
            Color.clear.frame(width: layout.labelGap, height: layout.headerHeight)

            ForEach(config.dates.indices, id: \.self) { dayIndex in
                Text(config.headerText(for: config.dates[dayIndex]))
                    .font(.caption.weight(.semibold))
                    .frame(width: layout.columnWidth, height: layout.headerHeight)
            }
        }
    }

    @ViewBuilder
    private func timeLabel(for row: Int, layout: GridLayout) -> some View {
        if row % 2 == 0 {
            Text(config.hourFormatter.string(from: dateFromMinutes(config.slotMinutes[row])))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.trailing, 2)
                .offset(y: -(layout.rowHeight / 2))
        } else {
            Color.clear
        }
    }

    private func slotCell(dayIndex: Int, row: Int) -> some View
    {
        let key = SlotSelection(dayIndex: dayIndex, slotIndex: row)
        let selected = selectedSlots.contains(key)
        let heat = config.heatLevel(dayIndex: dayIndex, slotIndex: row)

        // Precompute colors to avoid complex inline expressions that can stress the type-checker
        let baseFill: Color = {
            if let heat {
                let opacity = 0.18 + (heat * 0.72)
                return Color.green.opacity(opacity)
            } else {
                return Color.clear
            }
        }()

        let showSelection = (mode == .add) && selected
        let selectionFill: Color = showSelection ? Color.blue.opacity(0.25) : Color.clear
        let selectionStrokeColor: Color = showSelection ? Color.blue.opacity(0.96) : Color.clear
        let showInspected = (mode == .view) && (inspectedSlot == key)
        let inspectedStrokeColor: Color = showInspected ? Color.gray.opacity(0.9) : Color.clear

        return Rectangle()
            .fill(baseFill)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.6)
            )
            .overlay(
                Rectangle()
                    .fill(selectionFill)
            )
            .overlay(
                Rectangle()
                    .stroke(selectionStrokeColor, lineWidth: 1.1)
            )
            .overlay(
                Rectangle()
                    .stroke(inspectedStrokeColor, lineWidth: 1.4)
            )
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.14), value: showSelection)
            .animation(.easeInOut(duration: 0.12), value: showInspected)
            .onTapGesture {
                if mode == .view {
                    inspectedSlot = key
                } else {
                    if selectedSlots.contains(key) {
                        selectedSlots.remove(key)
                    } else {
                        selectedSlots.insert(key)
                    }
                }
            }
    }

    private func dragGesture(layout: GridLayout) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard let cell = layout.cell(at: value.location) else { return }
                let key = SlotSelection(dayIndex: cell.dayIndex, slotIndex: cell.row)

                if dragMode == nil {
                    dragMode = selectedSlots.contains(key) ? .remove : .add
                    dragAnchor = key
                    dragBaseSelection = selectedSlots
                }
                guard let dragMode, let dragAnchor else { return }

                let rectSlots = slotsInRectangle(from: dragAnchor, to: key)
                if dragMode == .add {
                    selectedSlots = dragBaseSelection.union(rectSlots)
                } else {
                    selectedSlots = dragBaseSelection.subtracting(rectSlots)
                }
            }
            .onEnded { _ in
                dragMode = nil
                dragAnchor = nil
                dragBaseSelection.removeAll()
            }
    }

    private func slotsInRectangle(from start: SlotSelection, to end: SlotSelection) -> Set<SlotSelection> {
        let minDay = min(start.dayIndex, end.dayIndex)
        let maxDay = max(start.dayIndex, end.dayIndex)
        let minSlot = min(start.slotIndex, end.slotIndex)
        let maxSlot = max(start.slotIndex, end.slotIndex)

        var result: Set<SlotSelection> = []
        for day in minDay...maxDay {
            for slot in minSlot...maxSlot {
                result.insert(SlotSelection(dayIndex: day, slotIndex: slot))
            }
        }
        return result
    }

    private func submitAvailability() {
        guard mode == .add else { return }
        guard let updated = config.urlAfterSubmitting(selection: selectedSlots) else { return }
        actions.insertEventLink(updated, config.name)
    }

    private func dateFromMinutes(_ minuteOfDay: Int) -> Date {
        let now = Date()
        let clamped = max(0, min(minuteOfDay, 24 * 60))
        if clamped == 24 * 60 {
            return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        }
        let hour = clamped / 60
        let minute = clamped % 60
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }
}

private enum DragMode {
    case add
    case remove
}

private enum AvailabilityMode {
    case view
    case add
}

private struct SlotSelection: Hashable {
    let dayIndex: Int
    let slotIndex: Int
}

private struct GridLayout {
    let spacing: CGFloat = 0
    let labelWidth: CGFloat = 44
    let labelGap: CGFloat = 8
    let headerHeight: CGFloat = 22
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    private let columnCount: Int
    private let rowCount: Int

    init(size: CGSize, columnCount: Int, rowCount: Int) {
        self.columnCount = max(1, columnCount)
        self.rowCount = max(1, rowCount)

        let totalHorizontalSpacing = spacing * CGFloat(self.columnCount)
        let availableWidth = max(1, size.width - labelWidth - labelGap - totalHorizontalSpacing)
        self.columnWidth = availableWidth / CGFloat(self.columnCount)

        let totalVerticalSpacing = spacing * CGFloat(self.rowCount)
        let availableHeight = max(1, size.height - headerHeight - totalVerticalSpacing)
        self.rowHeight = availableHeight / CGFloat(self.rowCount)
    }

    func cell(at point: CGPoint) -> (dayIndex: Int, row: Int)? {
        let gridStartX = labelWidth + labelGap + spacing
        let gridStartY = headerHeight + spacing

        let relativeX = point.x - gridStartX
        let relativeY = point.y - gridStartY
        guard relativeX >= 0, relativeY >= 0 else { return nil }

        let columnUnit = columnWidth + spacing
        let rowUnit = rowHeight + spacing

        let dayIndex = Int(relativeX / columnUnit)
        let row = Int(relativeY / rowUnit)
        guard dayIndex >= 0, dayIndex < columnCount, row >= 0, row < rowCount else { return nil }

        let insideCellX = relativeX.truncatingRemainder(dividingBy: columnUnit)
        let insideCellY = relativeY.truncatingRemainder(dividingBy: rowUnit)
        guard insideCellX <= columnWidth, insideCellY <= rowHeight else { return nil }

        return (dayIndex, row)
    }
}

private struct EventGridConfig {
    let sourceURL: URL?
    let name: String
    let dates: [Date]
    let slotMinutes: [Int]
    let dayHeaderFormatter: DateFormatter
    let shortDayHeaderFormatter: DateFormatter
    let hourFormatter: DateFormatter
    let responses: Int
    let voteCounts: [SlotSelection: Int]
    let startValue: String?
    let endValue: String?
    let datesValue: String?

    init(url: URL?) {
        self.sourceURL = url

        let params = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        let nameValue = params.first(where: { $0.name == "name" })?.value
        self.name = (nameValue?.isEmpty == false) ? (nameValue ?? "Event") : "Event"

        let dateParser = DateFormatter()
        dateParser.calendar = Calendar.current
        dateParser.locale = Locale(identifier: "en_US_POSIX")
        dateParser.timeZone = TimeZone.current
        dateParser.dateFormat = "yyyy-MM-dd"

        let rawDates = params.first(where: { $0.name == "dates" })?.value ?? ""
        let parsedDates = rawDates
            .split(separator: ",")
            .compactMap { dateParser.date(from: String($0)) }
            .sorted()
        self.dates = parsedDates.isEmpty ? [Calendar.current.startOfDay(for: Date())] : parsedDates

        let start = Self.parseISODate(params.first(where: { $0.name == "start" })?.value)
        let end = Self.parseISODate(params.first(where: { $0.name == "end" })?.value)
        self.startValue = params.first(where: { $0.name == "start" })?.value
        self.endValue = params.first(where: { $0.name == "end" })?.value
        self.datesValue = params.first(where: { $0.name == "dates" })?.value
        let (startMinute, endMinute) = Self.minuteRange(start: start, end: end)
        self.slotMinutes = stride(from: startMinute, to: endMinute, by: 30).map { $0 }

        let dayHeader = DateFormatter()
        dayHeader.setLocalizedDateFormatFromTemplate("EEE d")
        dayHeader.timeZone = TimeZone.current
        self.dayHeaderFormatter = dayHeader
        let shortDayHeader = DateFormatter()
        shortDayHeader.setLocalizedDateFormatFromTemplate("M/d")
        shortDayHeader.timeZone = TimeZone.current
        self.shortDayHeaderFormatter = shortDayHeader

        let hour = DateFormatter()
        hour.setLocalizedDateFormatFromTemplate("ha")
        hour.amSymbol = "AM"
        hour.pmSymbol = "PM"
        hour.timeZone = TimeZone.current
        self.hourFormatter = hour

        self.responses = Int(params.first(where: { $0.name == "responses" })?.value ?? "") ?? 0
        self.voteCounts = Self.parseVoteCounts(params.first(where: { $0.name == "votes" })?.value)
    }

    func heatLevel(dayIndex: Int, slotIndex: Int) -> Double? {
        guard responses > 0 else { return nil }

        let key = SlotSelection(dayIndex: dayIndex, slotIndex: slotIndex)
        let count = voteCounts[key] ?? 0
        guard count > 0 else { return nil }

        let maxCount = max(voteCounts.values.max() ?? 0, 1)
        return Double(count) / Double(maxCount)
    }

    func headerText(for date: Date) -> String {
        if dates.count > 5 {
            return shortDayHeaderFormatter.string(from: date)
        }
        return dayHeaderFormatter.string(from: date)
    }

    func tooltipTitle(for slot: SlotSelection) -> String {
        guard slot.dayIndex >= 0, slot.dayIndex < dates.count,
              slot.slotIndex >= 0, slot.slotIndex < slotMinutes.count else {
            return "Availability"
        }
        let day = headerText(for: dates[slot.dayIndex])
        let startMinute = slotMinutes[slot.slotIndex]
        let endMinute = min(startMinute + 30, 24 * 60)
        let time = "\(Self.timeRangeLabel(startMinute: startMinute, endMinute: endMinute))"
        return "\(day) • \(time)"
    }

    func peopleAvailable(dayIndex: Int, slotIndex: Int) -> [String] {
        let key = SlotSelection(dayIndex: dayIndex, slotIndex: slotIndex)
        let count = max(0, voteCounts[key] ?? 0)
        guard count > 0 else { return [] }
        return (1...count).map { "Person \($0)" }
    }

    func urlAfterSubmitting(selection: Set<SlotSelection>) -> URL? {
        var comps = URLComponents(url: sourceURL ?? URL(string: "qt://event")!, resolvingAgainstBaseURL: false)
        var counts = voteCounts

        for slot in selection {
            counts[slot, default: 0] += 1
        }

        let nextResponses = responses + 1
        let votesValue = Self.encodeVoteCounts(counts)

        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "name", value: name))

        if let startValue {
            items.append(URLQueryItem(name: "start", value: startValue))
        } else if let start = slotMinutes.first {
            items.append(URLQueryItem(name: "start", value: Self.isoString(from: Self.dateFromMinutes(start))))
        }
        if let endValue {
            items.append(URLQueryItem(name: "end", value: endValue))
        } else if let end = slotMinutes.last {
            let endMinute = min((end + 30), 24 * 60)
            items.append(URLQueryItem(name: "end", value: Self.isoString(from: Self.dateFromMinutes(endMinute))))
        }

        if let datesValue {
            items.append(URLQueryItem(name: "dates", value: datesValue))
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar.current
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let datesValue = dates.map { dateFormatter.string(from: $0) }.joined(separator: ",")
            items.append(URLQueryItem(name: "dates", value: datesValue))
        }

        items.append(URLQueryItem(name: "responses", value: String(nextResponses)))
        items.append(URLQueryItem(name: "votes", value: votesValue))

        comps?.queryItems = items
        return comps?.url
    }

    private static func parseVoteCounts(_ raw: String?) -> [SlotSelection: Int] {
        guard let raw, !raw.isEmpty else { return [:] }
        var result: [SlotSelection: Int] = [:]

        for token in raw.split(separator: ";") {
            let parts = token.split(separator: ":")
            guard parts.count == 2 else { continue }

            let indexPart = parts[0].split(separator: "-")
            guard indexPart.count == 2,
                  let day = Int(indexPart[0]),
                  let slot = Int(indexPart[1]),
                  let count = Int(parts[1]),
                  day >= 0,
                  slot >= 0,
                  count > 0 else { continue }

            result[SlotSelection(dayIndex: day, slotIndex: slot)] = count
        }

        return result
    }

    private static func encodeVoteCounts(_ counts: [SlotSelection: Int]) -> String {
        let entries = counts
            .filter { $0.value > 0 }
            .sorted {
                if $0.key.dayIndex == $1.key.dayIndex {
                    return $0.key.slotIndex < $1.key.slotIndex
                }
                return $0.key.dayIndex < $1.key.dayIndex
            }

        return entries
            .map { "\($0.key.dayIndex)-\($0.key.slotIndex):\($0.value)" }
            .joined(separator: ";")
    }

    private static func minuteRange(start: Date?, end: Date?) -> (Int, Int) {
        let cal = Calendar.current
        let defaultStart = 9 * 60
        let defaultEnd = 17 * 60

        guard let start, let end else { return (defaultStart, defaultEnd) }
        let startParts = cal.dateComponents([.hour, .minute], from: start)
        let endParts = cal.dateComponents([.hour, .minute], from: end)

        let rawStart = (startParts.hour ?? 9) * 60 + (startParts.minute ?? 0)
        let rawEnd = (endParts.hour ?? 17) * 60 + (endParts.minute ?? 0)

        let snappedStart = max(0, (rawStart / 30) * 30)
        let snappedEnd = min(24 * 60, ((rawEnd + 29) / 30) * 30)
        return snappedEnd > snappedStart ? (snappedStart, snappedEnd) : (defaultStart, defaultEnd)
    }

    private static func parseISODate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    private static func dateFromMinutes(_ minuteOfDay: Int) -> Date {
        let now = Date()
        let clamped = max(0, min(minuteOfDay, 24 * 60))
        if clamped == 24 * 60 {
            return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        }
        let hour = clamped / 60
        let minute = clamped % 60
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    private static func isoString(from date: Date) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.string(from: date)
    }

    private static func timeRangeLabel(startMinute: Int, endMinute: Int) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("h:mm a")
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.timeZone = TimeZone.current
        let start = formatter.string(from: dateFromMinutes(startMinute))
        let end = formatter.string(from: dateFromMinutes(endMinute))
        return "\(start) - \(end)"
    }
}

#Preview {
    EventLinkView()
}
