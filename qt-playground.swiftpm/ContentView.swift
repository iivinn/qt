import SwiftUI
import QtUI

struct ContentView: View {
    @State private var eventMessages: [EventMessage] = []
    @State private var selectedMessageID: UUID?
    @State private var transcriptScrollTarget: UUID?

    private var selectedMessageURL: URL? {
        eventMessages.first(where: { $0.id == selectedMessageID })?.url
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            transcriptPanel
            Divider()
            QtUI.ContentView(selectedMessageURL: selectedMessageURL)
                .environment(\.messagesActions, prototypeActions)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Fake iMessage")
                .font(.headline.weight(.semibold))
            Spacer()
            Button("New Event") {
                selectedMessageID = nil
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var transcriptPanel: some View {
        if eventMessages.isEmpty {
            Text("Create an event to generate a message bubble, then tap the bubble to open availability.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(eventMessages) { message in
                            transcriptRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
                .frame(maxHeight: 240)
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

    private func transcriptRow(_ message: EventMessage) -> some View {
        let isSelected = selectedMessageID == message.id
        let name = queryValue("name", in: message.url) ?? message.title
        let responses = queryValue("responses", in: message.url) ?? "0"

        return HStack {
            Spacer(minLength: 32)
            Button {
                selectedMessageID = message.id
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("When are you available for \(name)?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Text("\(responses) responses")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text(Self.timeFormatter.string(from: message.updatedAt ?? message.sentAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(width: 250, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue.opacity(0.55) : Color.gray.opacity(0.2), lineWidth: isSelected ? 1.3 : 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
        }
    }

    private var prototypeActions: MessagesActions {
        MessagesActions(
            requestExpanded: {},
            requestCompact: {
                selectedMessageID = nil
            },
            insertText: { _ in },
            insertEventLink: { url, title in
                withAnimation(.easeInOut(duration: 0.18)) {
                    if let selectedMessageID,
                       let index = eventMessages.firstIndex(where: { $0.id == selectedMessageID }) {
                        eventMessages[index].url = url
                        eventMessages[index].title = title
                        eventMessages[index].updatedAt = Date()
                        transcriptScrollTarget = selectedMessageID
                    } else {
                        let message = EventMessage(url: url, title: title, sentAt: Date(), updatedAt: nil)
                        eventMessages.append(message)
                        selectedMessageID = message.id
                        transcriptScrollTarget = message.id
                    }
                }
            }
        )
    }

    private func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
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
