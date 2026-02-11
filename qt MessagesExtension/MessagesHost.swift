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

        let layout = MSMessageTemplateLayout()
        layout.caption = title
        layout.subcaption = url.absoluteString
        message.layout = layout
        message.url = url

        conversation.insert(message, completionHandler: nil)
    }
}
