import SwiftUI

enum PanelState {
    case collapsed
    case card
    case full
}

struct PanelHeights {
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

struct EventMessage: Identifiable {
    let id: UUID
    var url: URL
    var title: String
    let sentAt: Date
    var updatedAt: Date?
    var direction: EventMessageDirection
    var senderName: String?

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        sentAt: Date,
        updatedAt: Date?,
        direction: EventMessageDirection = .outgoing,
        senderName: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.sentAt = sentAt
        self.updatedAt = updatedAt
        self.direction = direction
        self.senderName = senderName
    }
}

enum EventMessageDirection {
    case incoming
    case outgoing
}

struct GroupHistoryMessage {
    let sender: String
    let text: String
    let avatarColor: Color

    var initials: String {
        ChatSeedData.initials(for: sender)
    }
}

struct SlotKey: Hashable {
    let dayIndex: Int
    let slotIndex: Int
}

typealias SeededAvailabilityRecord = (name: String, slots: Set<SlotKey>)

enum ChatSeedData {
    static let groupHistoryMessages: [GroupHistoryMessage] = [
        GroupHistoryMessage(sender: "Abdul", text: "Hey guys! When's everyone free for DND?", avatarColor: .teal),
        GroupHistoryMessage(sender: "Joseph", text: "probably thursday or friday", avatarColor: .orange),
        GroupHistoryMessage(sender: "Bao", text: "Not free Friday, only Thursday", avatarColor: .indigo),
        GroupHistoryMessage(sender: "Ham", text: "i work thursday...", avatarColor: .mint),
        GroupHistoryMessage(sender: "Ken", text: "I can do Wednesday!", avatarColor: .pink)
    ]

    static let chatParticipantNames: [String] = {
        var seen = Set<String>()
        var names: [String] = []
        for message in groupHistoryMessages {
            if seen.insert(message.sender).inserted {
                names.append(message.sender)
            }
        }
        return names
    }()

    static func color(for sender: String, fallback: Color) -> Color {
        if let known = groupHistoryMessages.first(where: {
            $0.sender.compare(sender, options: .caseInsensitive) == .orderedSame
        }) {
            return known.avatarColor
        }
        return fallback
    }

    static func initials(for sender: String) -> String {
        let parts = sender.split(separator: " ")
        if let first = parts.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
}
