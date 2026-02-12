import Foundation

enum EventURLCodec {
    static func queryItems(from url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    static func value(for name: String, in items: [URLQueryItem]) -> String? {
        items.first(where: { $0.name == name })?.value
    }

    static func set(value: String, for name: String, in items: inout [URLQueryItem]) {
        items.removeAll { $0.name == name }
        items.append(URLQueryItem(name: name, value: value))
    }

    static func parseParticipantNames(queryItems: [URLQueryItem], fallback: [String]) -> [String] {
        let raw = queryItems.first(where: { $0.name == "participants" })?.value ?? ""
        var seen = Set<String>()
        let parsed = raw
            .split(separator: ",")
            .compactMap { token -> String? in
                let name = String(token).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                return seen.insert(name).inserted ? name : nil
            }

        if !parsed.isEmpty {
            return parsed
        }
        return fallback
    }

    static func parseDates(queryItems: [URLQueryItem]) -> [Date] {
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

    static func parseSlotMinutes(queryItems: [URLQueryItem], interval: Int = 30) -> [Int] {
        let step = max(1, interval)
        let start = parseISODate(queryItems.first(where: { $0.name == "start" })?.value)
        let end = parseISODate(queryItems.first(where: { $0.name == "end" })?.value)
        let range = minuteRange(start: start, end: end)
        return stride(from: range.start, to: range.end, by: step).map { $0 }
    }

    static func parseVoteCounts(_ raw: String?) -> [SlotKey: Int] {
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

    static func seedRecords(
        names: [String],
        dayCount: Int,
        slotCount: Int
    ) -> [SeededAvailabilityRecord] {
        guard dayCount > 0, slotCount > 0 else { return [] }
        var records: [SeededAvailabilityRecord] = []

        for (personIndex, name) in names.enumerated() {
            var slots: Set<SlotKey> = []

            for day in 0..<dayCount {
                if (personIndex + day) % 3 == 1 { continue }
                let base = (personIndex * 3 + day * 2) % max(slotCount, 1)
                let span = min(4 + (personIndex % 2), slotCount)
                for offset in 0..<span {
                    let slot = (base + offset) % slotCount
                    slots.insert(SlotKey(dayIndex: day, slotIndex: slot))
                }
            }

            if !slots.isEmpty {
                records.append((name: name, slots: slots))
            }
        }

        return records
    }

    static func encodeVotes(from records: [SeededAvailabilityRecord]) -> String {
        var counts: [SlotKey: Int] = [:]
        for record in records {
            for slot in record.slots {
                counts[slot, default: 0] += 1
            }
        }

        return counts
            .sorted {
                if $0.key.dayIndex == $1.key.dayIndex {
                    return $0.key.slotIndex < $1.key.slotIndex
                }
                return $0.key.dayIndex < $1.key.dayIndex
            }
            .map { "\($0.key.dayIndex)-\($0.key.slotIndex):\($0.value)" }
            .joined(separator: ";")
    }

    static func encodeRecords(from records: [SeededAvailabilityRecord]) -> String {
        records
            .map { record in
                let safeName = record.name
                    .replacingOccurrences(of: "|", with: " ")
                    .replacingOccurrences(of: "~", with: " ")
                    .replacingOccurrences(of: ",", with: " ")

                let slotValue = record.slots
                    .sorted {
                        if $0.dayIndex == $1.dayIndex {
                            return $0.slotIndex < $1.slotIndex
                        }
                        return $0.dayIndex < $1.dayIndex
                    }
                    .map { "\($0.dayIndex)-\($0.slotIndex)" }
                    .joined(separator: ",")
                return "\(safeName)~\(slotValue)"
            }
            .joined(separator: "|")
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
}
