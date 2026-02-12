import SwiftUI
import QtUI

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
                    GroupChatHeaderView()
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

    private var transcriptPanel: some View {
        TranscriptPanelView(
            historyMessages: ChatSeedData.groupHistoryMessages,
            eventMessages: eventMessages,
            selectedMessageID: selectedMessageID,
            transcriptScrollTarget: $transcriptScrollTarget,
            colorForSender: { sender, fallback in
                ChatSeedData.color(for: sender, fallback: fallback)
            },
            onEventTap: { message in
                selectedMessageID = message.id
                panelMessageID = message.id
                withAnimation(.easeOut(duration: 0.18)) {
                    panelDragOffset = 0
                    panelState = .card
                }
            }
        )
    }

    private var composerBar: some View {
        ComposerBarView(
            draftText: $draftText,
            onCreateEventTap: {
                selectedMessageID = nil
                panelMessageID = nil
                withAnimation(.easeOut(duration: 0.18)) {
                    panelDragOffset = 0
                    panelState = .card
                }
                panelSessionID = UUID()
            },
            onSendTap: {
                draftText = ""
            }
        )
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
                let participantsURL = eventURLWithParticipants(url)
                withAnimation(.easeInOut(duration: 0.2)) {
                    let targetMessageID = panelMessageID ?? selectedMessageID
                    if let targetMessageID,
                       let index = eventMessages.firstIndex(where: { $0.id == targetMessageID }) {
                        eventMessages[index].url = participantsURL
                        eventMessages[index].title = title
                        eventMessages[index].updatedAt = Date()
                        eventMessages[index].direction = .outgoing
                        eventMessages[index].senderName = nil
                        transcriptScrollTarget = targetMessageID
                    } else {
                        let incomingURL = incomingEventURL(withKenAvailabilityFrom: participantsURL)
                        let message = EventMessage(
                            url: incomingURL,
                            title: title,
                            sentAt: Date(),
                            updatedAt: nil,
                            direction: .incoming,
                            senderName: "Ken"
                        )
                        eventMessages.append(message)
                        transcriptScrollTarget = message.id
                    }

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

    private func eventURLWithParticipants(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        EventURLCodec.set(
            value: ChatSeedData.chatParticipantNames.joined(separator: ","),
            for: "participants",
            in: &items
        )
        components?.queryItems = items
        return components?.url ?? url
    }

    private func incomingEventURL(withKenAvailabilityFrom url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []

        let existingResponses = Int(EventURLCodec.value(for: "responses", in: items) ?? "") ?? 0
        let existingVotes = EventURLCodec.value(for: "votes", in: items) ?? ""
        let existingRecords = EventURLCodec.value(for: "records", in: items) ?? ""
        if existingResponses > 0 || !existingVotes.isEmpty || !existingRecords.isEmpty {
            return url
        }

        let dayCount = max(1, EventURLCodec.parseDates(queryItems: items).count)
        let slotMinutes = EventURLCodec.parseSlotMinutes(queryItems: items)
        let slotCount = max(1, slotMinutes.count)
        let participantNames = EventURLCodec.parseParticipantNames(
            queryItems: items,
            fallback: ChatSeedData.chatParticipantNames
        )
        let records = EventURLCodec.seedRecords(
            names: participantNames,
            dayCount: dayCount,
            slotCount: slotCount
        )
        let votes = EventURLCodec.encodeVotes(from: records)
        let recordsValue = EventURLCodec.encodeRecords(from: records)

        EventURLCodec.set(value: String(records.count), for: "responses", in: &items)
        EventURLCodec.set(value: votes, for: "votes", in: &items)
        EventURLCodec.set(value: recordsValue, for: "records", in: &items)
        components?.queryItems = items
        return components?.url ?? url
    }
}
