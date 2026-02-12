import SwiftUI
import QtUI
import UIKit

struct ContentView: View {
    @State private var eventMessages: [EventMessage] = []
    @State private var selectedMessageID: UUID?
    @State private var panelMessageID: UUID?
    @State private var transcriptScrollTarget: UUID?
    @State private var draftText: String = ""
    @State private var panelState: PanelState = .collapsed
    @State private var panelSessionID = UUID()
    @State private var panelDragOffset: CGFloat = 0
    @State private var panelIsDragging: Bool = false
    @State private var panelIsSettling: Bool = false

    private var selectedMessageURL: URL? {
        let targetID = panelMessageID ?? selectedMessageID
        return eventMessages.first(where: { $0.id == targetID })?.url
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header
                    transcriptPanel
                    composerBar
                }
                .background(Color(.systemGroupedBackground))
                .ignoresSafeArea(.keyboard, edges: .bottom)

                panelSheet(in: geo)
                    .allowsHitTesting(panelState != .collapsed)
                    .opacity(panelState == .collapsed ? 0 : 1)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "person.fill").foregroundStyle(.white).font(.caption))

            VStack(alignment: .leading, spacing: 1) {
                Text("Ivin")
                    .font(.headline.weight(.semibold))
                Text("iMessage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var transcriptPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    introRow

                    ForEach(eventMessages) { message in
                        transcriptRow(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemBackground))
            .onAppear {
                if let id = eventMessages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .onChange(of: transcriptScrollTarget) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    private var introRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 26, height: 26)
                .overlay(Image(systemName: "person.fill").foregroundStyle(.white).font(.caption2))

            Text("Hey guys! What's the best day for DND?")
                .font(.footnote)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                )

            Spacer(minLength: 44)
        }
    }

    private func transcriptRow(_ message: EventMessage) -> some View {
        let isSelected = selectedMessageID == message.id
        let preview = EventBubblePreview(url: message.url, fallbackTitle: message.title)

        return HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 44)

            Button {
                selectedMessageID = message.id
                panelMessageID = message.id
                withAnimation(.easeOut(duration: 0.18)) {
                    panelDragOffset = 0
                    panelState = .card
                }
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    if let image = preview.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text(preview.caption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(preview.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.86))

                        Spacer(minLength: 0)

                        Text(Self.timeFormatter.string(from: message.updatedAt ?? message.sentAt))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .padding(10)
                .frame(width: 266, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1.25)
                )
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(Color.blue.opacity(0.75))
                .frame(width: 24, height: 24)
                .overlay(Image(systemName: "person.fill").foregroundStyle(.white).font(.caption2))
        }
    }

    private var composerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("iMessage", text: $draftText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)

                Button {
                    selectedMessageID = nil
                    panelMessageID = nil
                    withAnimation(.easeOut(duration: 0.18)) {
                        panelDragOffset = 0
                        panelState = .card
                    }
                    panelSessionID = UUID()
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(Color.white)
                        .background(Circle().fill(Color.blue))
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            Button {
                draftText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.35) : Color.blue)
            }
            .buttonStyle(.plain)
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func panelSheet(in geo: GeometryProxy) -> some View {
        let heights = PanelHeights(geo: geo)
        let collapsedOffset = panelYOffset(for: .collapsed, heights: heights)
        let baseOffset = panelYOffset(for: panelState, heights: heights)
        let liveOffset = clamp(baseOffset + panelDragOffset, min: 0, max: collapsedOffset)
        let isFullscreen = panelState == .full
        let cornerRadius: CGFloat = isFullscreen ? 0 : 18
        let horizontalInset: CGFloat = isFullscreen ? 0 : 6
        let bottomInset: CGFloat = isFullscreen ? 0 : 6
        let shadowOpacity: CGFloat = isFullscreen ? 0 : 0.16

        return VStack(spacing: 0) {
            ZStack {
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 38, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
            .highPriorityGesture(panelDragGesture(heights: heights))

            Divider()

            QtUI.ContentView(selectedMessageURL: selectedMessageURL)
                .id(panelSessionID)
                .environment(\.messagesActions, prototypeActions)
                .allowsHitTesting(!(panelIsDragging || panelIsSettling))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: heights.full, alignment: .top)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(shadowOpacity * 0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(shadowOpacity), radius: 8, y: -1)
        .offset(y: liveOffset)
        .padding(.horizontal, horizontalInset)
        .padding(.bottom, bottomInset)
        .ignoresSafeArea(edges: .bottom)
    }

    private func panelDragGesture(heights: PanelHeights) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                panelIsDragging = true
                panelDragOffset = value.translation.height
            }
            .onEnded { value in
                let baseOffset = panelYOffset(for: panelState, heights: heights)
                let collapsedOffset = panelYOffset(for: .collapsed, heights: heights)
                let projectedOffset = clamp(baseOffset + value.translation.height, min: 0, max: collapsedOffset)
                let nextState = targetPanelState(
                    current: panelState,
                    translation: value.translation.height,
                    projectedOffset: projectedOffset,
                    heights: heights
                )

                panelIsSettling = true
                panelDragOffset = 0
                panelState = nextState
                if nextState == .collapsed {
                    selectedMessageID = nil
                    panelMessageID = nil
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    panelIsDragging = false
                    panelIsSettling = false
                }
            }
    }

    private func panelYOffset(for state: PanelState, heights: PanelHeights) -> CGFloat {
        switch state {
        case .full:
            return 0
        case .card:
            return max(0, heights.full - heights.card)
        case .collapsed:
            return heights.full + 28
        }
    }

    private func targetPanelState(
        current: PanelState,
        translation: CGFloat,
        projectedOffset: CGFloat,
        heights: PanelHeights
    ) -> PanelState {
        let threshold: CGFloat = 68
        if abs(translation) < threshold {
            return nearestPanelState(for: projectedOffset, heights: heights)
        }

        switch current {
        case .full:
            return translation > 0 ? .card : .full
        case .card:
            return translation < 0 ? .full : .collapsed
        case .collapsed:
            return translation < 0 ? .card : .collapsed
        }
    }

    private func nearestPanelState(for offset: CGFloat, heights: PanelHeights) -> PanelState {
        let fullOffset = panelYOffset(for: .full, heights: heights)
        let cardOffset = panelYOffset(for: .card, heights: heights)
        let collapsedOffset = panelYOffset(for: .collapsed, heights: heights)

        if offset <= (fullOffset + cardOffset) * 0.5 {
            return .full
        }
        if offset >= (cardOffset + collapsedOffset) * 0.5 {
            return .collapsed
        }
        return .card
    }

    private func clamp<T: Comparable>(_ value: T, min lower: T, max upper: T) -> T {
        Swift.min(Swift.max(value, lower), upper)
    }

    private var prototypeActions: MessagesActions {
        MessagesActions(
            requestExpanded: {
                withAnimation(.easeOut(duration: 0.18)) {
                    panelDragOffset = 0
                    panelIsDragging = false
                    panelIsSettling = false
                    if panelState == .collapsed {
                        panelState = .card
                    }
                }
            },
            requestCompact: {
                withAnimation(.easeOut(duration: 0.18)) {
                    panelDragOffset = 0
                    panelIsDragging = false
                    panelIsSettling = false
                    panelState = .collapsed
                    selectedMessageID = nil
                    panelMessageID = nil
                    panelSessionID = UUID()
                }
            },
            insertText: { _ in },
            insertEventLink: { url, title in
                withAnimation(.easeInOut(duration: 0.2)) {
                    let targetMessageID = panelMessageID ?? selectedMessageID
                    if let targetMessageID,
                       let index = eventMessages.firstIndex(where: { $0.id == targetMessageID }) {
                        eventMessages[index].url = url
                        eventMessages[index].title = title
                        eventMessages[index].updatedAt = Date()
                        transcriptScrollTarget = targetMessageID
                    } else {
                        let message = EventMessage(url: url, title: title, sentAt: Date(), updatedAt: nil)
                        eventMessages.append(message)
                        transcriptScrollTarget = message.id
                    }

                    // Match iMessage-like flow: send/update then collapse extension UI.
                    selectedMessageID = nil
                    panelMessageID = nil
                    panelDragOffset = 0
                    panelIsDragging = false
                    panelIsSettling = false
                    panelState = .collapsed
                    panelSessionID = UUID()
                }
            }
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private enum PanelState {
    case collapsed
    case card
    case full
}

private struct PanelHeights {
    let card: CGFloat
    let full: CGFloat

    init(geo: GeometryProxy) {
        let availableHeight = max(320, geo.size.height - geo.safeAreaInsets.top)
        self.full = availableHeight
        self.card = min(430, availableHeight * 0.72)
    }

    func height(for state: PanelState) -> CGFloat {
        switch state {
        case .collapsed:
            return 0
        case .card:
            return card
        case .full:
            return full
        }
    }
}

private struct EventMessage: Identifiable {
    let id: UUID
    var url: URL
    var title: String
    let sentAt: Date
    var updatedAt: Date?

    init(id: UUID = UUID(), url: URL, title: String, sentAt: Date, updatedAt: Date?) {
        self.id = id
        self.url = url
        self.title = title
        self.sentAt = sentAt
        self.updatedAt = updatedAt
    }
}

private struct SlotKey: Hashable {
    let dayIndex: Int
    let slotIndex: Int
}

private struct EventBubblePreview {
    let caption: String
    let subtitle: String
    let image: UIImage?

    init(url: URL, fallbackTitle: String) {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let name = queryItems.first(where: { $0.name == "name" })?.value
        let resolvedName = (name?.isEmpty == false) ? (name ?? fallbackTitle) : fallbackTitle
        self.caption = "When are you available for \(resolvedName)?"

        let responses = Int(queryItems.first(where: { $0.name == "responses" })?.value ?? "") ?? 0
        self.subtitle = "\(responses) responses"

        let dates = Self.parseDates(queryItems)
        let slotMinutes = Self.parseSlotMinutes(queryItems)
        let voteCounts = Self.parseVoteCounts(queryItems.first(where: { $0.name == "votes" })?.value)
        self.image = Self.renderHeatmapImage(
            dates: dates,
            slotMinutes: slotMinutes,
            responses: responses,
            voteCounts: voteCounts
        )
    }

    private static func parseDates(_ queryItems: [URLQueryItem]) -> [Date] {
        let dateParser = DateFormatter()
        dateParser.calendar = Calendar.current
        dateParser.locale = Locale(identifier: "en_US_POSIX")
        dateParser.timeZone = TimeZone.current
        dateParser.dateFormat = "yyyy-MM-dd"

        let rawDates = queryItems.first(where: { $0.name == "dates" })?.value ?? ""
        let parsedDates = rawDates
            .split(separator: ",")
            .compactMap { dateParser.date(from: String($0)) }
            .sorted()

        return parsedDates.isEmpty ? [Calendar.current.startOfDay(for: Date())] : parsedDates
    }

    private static func parseSlotMinutes(_ queryItems: [URLQueryItem]) -> [Int] {
        let start = parseISODate(queryItems.first(where: { $0.name == "start" })?.value)
        let end = parseISODate(queryItems.first(where: { $0.name == "end" })?.value)
        let minuteRange = minuteRange(start: start, end: end)
        return stride(from: minuteRange.start, to: minuteRange.end, by: 30).map { $0 }
    }

    private static func renderHeatmapImage(
        dates: [Date],
        slotMinutes: [Int],
        responses: Int,
        voteCounts: [SlotKey: Int]
    ) -> UIImage? {
        let size = CGSize(width: 312, height: 156)
        let renderer = UIGraphicsImageRenderer(size: size)
        let dayCount = max(1, dates.count)
        let startMinute = slotMinutes.first ?? (9 * 60)
        let endMinute = (slotMinutes.last.map { min($0 + 30, 24 * 60) }) ?? (17 * 60)
        let hourRows = stride(from: startMinute, to: endMinute, by: 60).map { $0 }
        let rowMinutes = hourRows.isEmpty ? [startMinute] : hourRows
        let rowCount = rowMinutes.count
        let maxCount = max(voteCounts.values.max() ?? 0, 1)

        let dayFormatter = DateFormatter()
        if dayCount > 5 {
            dayFormatter.setLocalizedDateFormatFromTemplate("M/d")
        } else {
            dayFormatter.setLocalizedDateFormatFromTemplate("EEE d")
        }
        dayFormatter.timeZone = TimeZone.current

        let hourFormatter = DateFormatter()
        hourFormatter.setLocalizedDateFormatFromTemplate("ha")
        hourFormatter.amSymbol = "AM"
        hourFormatter.pmSymbol = "PM"
        hourFormatter.timeZone = TimeZone.current

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.systemBackground.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let margin: CGFloat = 8
            let labelWidth: CGFloat = 28
            let headerHeight: CGFloat = 14
            let gridX = margin + labelWidth
            let gridY = margin + headerHeight
            let gridW = size.width - gridX - margin
            let gridH = size.height - gridY - margin
            let colW = gridW / CGFloat(dayCount)
            let rowH = gridH / CGFloat(rowCount)

            for dayIndex in 0..<dayCount {
                let text = dayFormatter.string(from: dates[dayIndex])
                let rect = CGRect(x: gridX + CGFloat(dayIndex) * colW, y: margin, width: colW, height: headerHeight)
                text.draw(in: rect, withAttributes: titleAttrs)
            }

            for row in 0..<rowCount {
                let text = hourFormatter.string(from: dateFromMinutes(rowMinutes[row]))
                let y = gridY + CGFloat(row) * rowH
                let rect = CGRect(x: margin, y: y, width: labelWidth - 2, height: rowH)
                text.draw(in: rect, withAttributes: labelAttrs)
            }

            for dayIndex in 0..<dayCount {
                for row in 0..<rowCount {
                    let cellRect = CGRect(
                        x: gridX + CGFloat(dayIndex) * colW,
                        y: gridY + CGFloat(row) * rowH,
                        width: colW,
                        height: rowH
                    )

                    var count = 0
                    let baseSlot = row * 2
                    for bucket in 0..<2 {
                        let slotIndex = baseSlot + bucket
                        guard slotIndex < slotMinutes.count else { continue }
                        count = max(count, voteCounts[SlotKey(dayIndex: dayIndex, slotIndex: slotIndex)] ?? 0)
                    }

                    if responses > 0 && count > 0 {
                        let heat = CGFloat(Double(count) / Double(maxCount))
                        UIColor.systemGreen.withAlphaComponent(0.18 + heat * 0.72).setFill()
                        cg.fill(cellRect)
                    }

                    UIColor.separator.withAlphaComponent(0.4).setStroke()
                    cg.setLineWidth(0.5)
                    cg.stroke(cellRect)
                }
            }
        }
    }

    private static func parseVoteCounts(_ raw: String?) -> [SlotKey: Int] {
        guard let raw, !raw.isEmpty else { return [:] }
        var result: [SlotKey: Int] = [:]

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

            result[SlotKey(dayIndex: day, slotIndex: slot)] = count
        }
        return result
    }

    private static func parseISODate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    private static func minuteRange(start: Date?, end: Date?) -> (start: Int, end: Int) {
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
        if snappedEnd > snappedStart {
            return (snappedStart, snappedEnd)
        }
        return (defaultStart, defaultEnd)
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
}
