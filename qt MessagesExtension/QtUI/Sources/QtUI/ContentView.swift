//
//  RootView.swift
//  qt
//
//  Created by ivin on 2/10/26.
//

import SwiftUI

public struct ContentView: View {
    private let selectedMessageURL: URL?

    public init(selectedMessageURL: URL? = nil) {
        self.selectedMessageURL = selectedMessageURL
    }

    public var body: some View {
        if isEventURL(selectedMessageURL) {
            EventLinkView(eventURL: selectedMessageURL)
        } else {
            NewEventView()
        }
    }

    private func isEventURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        guard url.scheme == "qt" else { return false }
        if url.host == "event" { return true }
        if url.pathComponents.contains("event") { return true }
        return url.absoluteString.hasPrefix("qt:event")
    }
}

#Preview {
    ContentView()
}
