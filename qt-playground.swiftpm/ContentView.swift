import SwiftUI
import QtUI

struct ContentView: View {
    @State private var eventMessages: [EventMessage] = []
    @State private var selectedMessageID: UUID?

    private var selectedMessageURL: URL? {
        eventMessages.first(where: { $0.id == selectedMessageID })?.url
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            transcript
            Divider()
            QtUI.ContentView(selectedMessageURL: selectedMessageURL)
                .environment(\.messagesActions, prototypeActions)
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Text("Messages Prototype")
                .font(.headline)
            Spacer()
            Button("New Event") {
                selectedMessageID = nil
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private var transcript: some View {
        if eventMessages.isEmpty {
            Text("Create an event to generate a message bubble, then tap it to open availability.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(eventMessages) { message in
                        messageBubble(message)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func messageBubble(_ message: EventMessage) -> some View {
        let isSelected = selectedMessageID == message.id
        let name = queryValue("name", in: message.url) ?? message.title
        let responses = queryValue("responses", in: message.url) ?? "0"

        return Button {
            selectedMessageID = message.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("When are you available for \(name)?")
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text("\(responses) responses")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.45) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var prototypeActions: MessagesActions {
        MessagesActions(
            requestExpanded: {},
            requestCompact: {
                selectedMessageID = nil
            },
            insertText: { _ in },
            insertEventLink: { url, title in
                let message = EventMessage(url: url, title: title)
                withAnimation(.easeInOut(duration: 0.18)) {
                    eventMessages.append(message)
                    selectedMessageID = nil
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
}

private struct EventMessage: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}
