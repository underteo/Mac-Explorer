import Foundation
import SwiftUI

@MainActor
enum PaneController {
    static func reload(
        _ pane: inout PaneState,
        using filesystem: DirectoryListingService,
        keepFoldersOnTop: Bool = true
    ) async {
        pane.isLoading = true
        pane.errorMessage = nil
        let url = pane.currentURL
        let sortKey = pane.sortKey
        let ascending = pane.sortAscending
        do {
            let items = try await Task.detached(priority: .userInitiated) {
                try filesystem.listContents(
                    of: url,
                    sortKey: sortKey,
                    ascending: ascending,
                    keepFoldersOnTop: keepFoldersOnTop
                )
            }.value
            pane.items = items
            pane.selectedURLs = pane.selectedURLs.intersection(Set(items.map(\.url)))
            pane.titleSync()
        } catch {
            pane.items = []
            pane.errorMessage = error.localizedDescription
        }
        pane.isLoading = false
    }

    static func navigate(
        _ pane: inout PaneState,
        to url: URL,
        using filesystem: DirectoryListingService,
        recordHistory: Bool = true,
        keepFoldersOnTop: Bool = true
    ) async {
        if recordHistory {
            pane.history.navigate(to: url)
        }
        pane.currentURL = url
        pane.selectedURLs = []
        await reload(&pane, using: filesystem, keepFoldersOnTop: keepFoldersOnTop)
    }

    static func goBack(
        _ pane: inout PaneState,
        using filesystem: DirectoryListingService,
        keepFoldersOnTop: Bool = true
    ) async {
        guard let url = pane.history.goBack() else { return }
        pane.currentURL = url
        pane.selectedURLs = []
        await reload(&pane, using: filesystem, keepFoldersOnTop: keepFoldersOnTop)
    }

    static func goForward(
        _ pane: inout PaneState,
        using filesystem: DirectoryListingService,
        keepFoldersOnTop: Bool = true
    ) async {
        guard let url = pane.history.goForward() else { return }
        pane.currentURL = url
        pane.selectedURLs = []
        await reload(&pane, using: filesystem, keepFoldersOnTop: keepFoldersOnTop)
    }
}

private extension PaneState {
    mutating func titleSync() {
        // Title lives on tab; pane only holds URL.
        _ = currentURL
    }
}
