import UIKit

struct EventBubblePreview {
    let caption: String
    let subtitle: String
    let image: UIImage?

    init(url: URL, fallbackTitle: String) {
        let queryItems = EventURLCodec.queryItems(from: url)
        let name = queryItems.first(where: { $0.name == "name" })?.value
        let resolvedName = (name?.isEmpty == false) ? (name ?? fallbackTitle) : fallbackTitle
        self.caption = "When are you available for \(resolvedName)?"

        let responses = Int(queryItems.first(where: { $0.name == "responses" })?.value ?? "") ?? 0
        self.subtitle = "\(responses) responses"

        let dates = EventURLCodec.parseDates(queryItems: queryItems)
        let slotMinutes = EventURLCodec.parseSlotMinutes(queryItems: queryItems)
        let voteCounts = EventURLCodec.parseVoteCounts(queryItems.first(where: { $0.name == "votes" })?.value)
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
