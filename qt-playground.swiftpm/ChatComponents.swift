import SwiftUI
import UIKit

struct GroupChatHeaderView: View {
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text("🎲")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.blue))
                Text("DND 🐉")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct TranscriptPanelView: View {
    let historyMessages: [GroupHistoryMessage]
    let eventMessages: [EventMessage]
    let selectedMessageID: UUID?
    @Binding var transcriptScrollTarget: UUID?
    let colorForSender: (String, Color) -> Color
    let onEventTap: (EventMessage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(historyMessages.indices, id: \.self) { index in
                        HistoryMessageRowView(message: historyMessages[index])
                    }

                    ForEach(eventMessages) { message in
                        EventTranscriptRowView(
                            message: message,
                            isSelected: selectedMessageID == message.id,
                            incomingAvatarColor: colorForSender(message.senderName ?? "Ken", .gray),
                            onTap: {
                                onEventTap(message)
                            }
                        )
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
}

struct HistoryMessageRowView: View {
    let message: GroupHistoryMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(message.avatarColor.opacity(0.9))
                .frame(width: 26, height: 26)
                .overlay(Text(message.initials).font(.caption2.weight(.semibold)).foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 2) {
                Text(message.sender)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message.text)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemBackground))
                    )
            }

            Spacer(minLength: 44)
        }
    }
}

struct EventTranscriptRowView: View {
    let message: EventMessage
    let isSelected: Bool
    let incomingAvatarColor: Color
    let onTap: () -> Void

    var body: some View {
        let preview = EventBubblePreview(url: message.url, fallbackTitle: message.title)
        let isIncoming = message.direction == .incoming

        return HStack(alignment: .bottom, spacing: 8) {
            if isIncoming {
                let sender = message.senderName ?? "Ken"
                ChatAvatarView(sender: sender, color: incomingAvatarColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sender)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    EventMessageBubbleButton(
                        message: message,
                        preview: preview,
                        isSelected: isSelected,
                        isIncoming: true,
                        onTap: onTap
                    )
                }

                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)

                EventMessageBubbleButton(
                    message: message,
                    preview: preview,
                    isSelected: isSelected,
                    isIncoming: false,
                    onTap: onTap
                )

                ChatAvatarView(sender: "You", color: .blue)
            }
        }
    }
}

struct EventMessageBubbleButton: View {
    let message: EventMessage
    let preview: EventBubblePreview
    let isSelected: Bool
    let isIncoming: Bool
    let onTap: () -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    var body: some View {
        let bubbleFill = isIncoming ? Color(.systemBackground) : Color.blue
        let titleColor = isIncoming ? Color.primary : Color.white
        let subtitleColor = isIncoming ? Color.secondary : Color.white.opacity(0.86)
        let timeColor = isIncoming ? Color.secondary.opacity(0.85) : Color.white.opacity(0.82)
        let selectedStroke = isIncoming ? Color.gray.opacity(0.5) : Color.white.opacity(0.8)

        return Button(action: onTap) {
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
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(preview.subtitle)
                        .font(.caption2)
                        .foregroundStyle(subtitleColor)

                    Spacer(minLength: 0)

                    Text(Self.timeFormatter.string(from: message.updatedAt ?? message.sentAt))
                        .font(.caption2)
                        .foregroundStyle(timeColor)
                }
            }
            .padding(10)
            .frame(width: 266, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(bubbleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? selectedStroke : Color.clear, lineWidth: 1.25)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct ChatAvatarView: View {
    let sender: String
    let color: Color

    var body: some View {
        Circle()
            .fill(color.opacity(0.85))
            .frame(width: 24, height: 24)
            .overlay(
                Text(ChatSeedData.initials(for: sender))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            )
    }
}

struct ComposerBarView: View {
    @Binding var draftText: String
    let onCreateEventTap: () -> Void
    let onSendTap: () -> Void

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Tap the blue button to create an event!", text: $draftText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)

                Button(action: onCreateEventTap) {
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

            Button(action: onSendTap) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(canSend ? Color.blue : Color.gray.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
}
