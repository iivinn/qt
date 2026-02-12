//
//  MessagesHost.swift
//  qt
//
//  Created by ivin on 2/11/26.
//

import Messages
import UIKit

@MainActor
final class MessagesHost {
    weak var controller: MSMessagesAppViewController?
    private(set) var conversation: MSConversation?

    init(controller: MSMessagesAppViewController) {
        self.controller = controller
    }

    func updateConversation(_ conversation: MSConversation?) {
        self.conversation = conversation
    }

    func requestExpanded() {
        controller?.requestPresentationStyle(.expanded)
    }

    func requestCompact() {
        controller?.requestPresentationStyle(.compact)
    }

    func insertText(_ text: String) {
        conversation?.insertText(text, completionHandler: nil)
    }

    func insertEventLink(_ url: URL, title: String) {
        guard let conversation else { return }

        let session = conversation.selectedMessage?.session ?? MSSession()
        let message = MSMessage(session: session)
        let preview = EventMessagePreview(url: url, fallbackTitle: title)

        let layout = MSMessageTemplateLayout()
        layout.caption = preview.caption
        layout.subcaption = EncodedEventURL.pack(url: url, visible: preview.subtitle)
        layout.trailingSubcaption = nil
        layout.image = preview.image
        message.layout = layout
        message.url = url
        message.summaryText = EncodedEventURL.pack(url: url, visible: "")

        conversation.insert(message, completionHandler: nil)
        controller?.dismiss()
    }
}

private struct SlotKey: Hashable {
    let dayIndex: Int
    let slotIndex: Int
}

private struct EventMessagePreview {
    let caption: String
    let subtitle: String
    let image: UIImage?

    private let dates: [Date]
    private let slotMinutes: [Int]
    private let responses: Int
    private let voteCounts: [SlotKey: Int]

    init(url: URL, fallbackTitle: String) {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let name = queryItems.first(where: { $0.name == "name" })?.value
        let resolvedName = (name?.isEmpty == false) ? (name ?? fallbackTitle) : fallbackTitle
        self.caption = "When are you available for \(resolvedName)?"

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
        self.dates = parsedDates.isEmpty ? [Calendar.current.startOfDay(for: Date())] : parsedDates

        let startDate = Self.parseISODate(queryItems.first(where: { $0.name == "start" })?.value)
        let endDate = Self.parseISODate(queryItems.first(where: { $0.name == "end" })?.value)
        let minuteRange = Self.minuteRange(start: startDate, end: endDate)
        self.slotMinutes = stride(from: minuteRange.start, to: minuteRange.end, by: 30).map { $0 }

        self.responses = Int(queryItems.first(where: { $0.name == "responses" })?.value ?? "") ?? 0
        self.voteCounts = Self.parseVoteCounts(queryItems.first(where: { $0.name == "votes" })?.value)

        self.subtitle = "\(responses) responses"
        self.image = Self.renderHeatmapImage(
            dates: dates,
            slotMinutes: slotMinutes,
            responses: responses,
            voteCounts: voteCounts
        )
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
            let footerHeight: CGFloat = 0
            let gridX = margin + labelWidth
            let gridY = margin + headerHeight
            let gridW = size.width - gridX - margin
            let gridH = size.height - gridY - margin - footerHeight
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

private enum EncodedEventURL {
    private static let lead = "\u{2063}"
    private static let zero = "\u{200B}"
    private static let one = "\u{200C}"

    static func pack(url: URL, visible: String) -> String {
        let data = Data(url.absoluteString.utf8)
        let bitString = data.map { byte -> String in
            (0..<8).reversed().map { bit in
                (Int(byte) & (1 << bit)) != 0 ? one : zero
            }.joined()
        }.joined()
        return visible + lead + bitString
    }
}
