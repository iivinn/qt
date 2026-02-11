//
//  MessagesActions.swift
//  QtUI
//
//  Created by ivin on 2/11/26.
//

import SwiftUI

// Small set of actions the SwiftUI package can ask the host (Messages extension) to perform.
// This avoids importing `Messages` into the package.
public struct MessagesActions: Sendable {
    public var requestExpanded: @MainActor () -> Void
    public var requestCompact: @MainActor () -> Void
    public var insertText: @MainActor (String) -> Void
    public var insertEventLink: @MainActor (_ url: URL, _ title: String) -> Void

    public init(
        requestExpanded: @escaping @MainActor () -> Void = {},
        requestCompact: @escaping @MainActor () -> Void = {},
        insertText: @escaping @MainActor (String) -> Void = { _ in },
        insertEventLink: @escaping @MainActor (URL, String) -> Void = { _, _ in }
    ) {
        self.requestExpanded = requestExpanded
        self.requestCompact = requestCompact
        self.insertText = insertText
        self.insertEventLink = insertEventLink
    }
}

private struct MessagesActionsKey: EnvironmentKey {
    static let defaultValue = MessagesActions()
}

public extension EnvironmentValues {
    var messagesActions: MessagesActions {
        get { self[MessagesActionsKey.self] }
        set { self[MessagesActionsKey.self] = newValue }
    }
}
