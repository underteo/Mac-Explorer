import SwiftUI

struct PaneBrowserView: View {
    @EnvironmentObject private var app: AppModel
    @Binding var pane: PaneState
    let isPrimary: Bool
    let onOpen: (FileItem) -> Void
    /// Focus a directory in this pane without the “open folders in tabs” preference (column view).
    /// Second argument is the selection to restore after navigation (folder or file URLs).
    var onFocusDirectory: ((URL, Set<URL>) -> Void)? = nil
    let onTrash: () -> Void
    let onRename: (FileItem) -> Void
    let onRefresh: () -> Void
    let onCreated: (URL) -> Void
    let onPaste: () -> Void
    let onActivate: () -> Void
    var onOpenInNewPane: (URL) -> Void = { _ in }
    var onShowViewOptions: () -> Void = {}
    var renameURL: URL?
    @Binding var renameText: String
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void

    private var menuCallbacks: FileMenuCallbacks {
        FileMenuCallbacks(
            onRename: onRename,
            onTrash: onTrash,
            onRefresh: onRefresh,
            onCreated: onCreated,
            onPaste: onPaste,
            onOpenInNewPane: onOpenInNewPane,
            onSort: { key in
                pane.sortKey = key
                onRefresh()
            },
            onShowViewOptions: onShowViewOptions
        )
    }

    private var displayedItems: [FileItem] {
        guard showsSearchResults else { return pane.items }
        // While the async search runs, filter locally so the list reacts immediately.
        if app.selectedTab.isSearching {
            let query = app.selectedTab.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            return pane.items.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        // Include empty results so "no matches" does not fall back to the full folder.
        return app.selectedTab.searchResults
    }

    private var showsSearchResults: Bool {
        guard app.selectedTab.hasActiveSearch else { return false }
        if !app.dualPaneEnabled { return isPrimary }
        return isPrimary
            ? app.selectedTab.searchPaneID == .primary
            : app.selectedTab.searchPaneID == .secondary
    }

    var body: some View {
        VStack(spacing: 0) {
            // Dual-pane only: name + view switcher. Single-pane already has path bar / toolbar
            // (extra strip here looked like empty dead space above column headers).
            if app.dualPaneEnabled {
                paneChrome
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.background)
        .onChange(of: pane.selectedURLs) { _, _ in
            onActivate()
        }
        .onChange(of: pane.viewMode) { _, _ in
            onActivate()
        }
    }

    private var paneChrome: some View {
        HStack(spacing: 8) {
            Text(pane.currentURL.lastPathComponent)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 4)

            ExplorerViewModePicker(viewMode: $pane.viewMode, compact: true)

            Button {
                onActivate()
                if app.isFavorite(pane.currentURL) {
                    app.removeFavorite(url: pane.currentURL)
                } else {
                    _ = app.addFavorite(pane.currentURL)
                }
            } label: {
                Image(systemName: app.isFavorite(pane.currentURL) ? "star.fill" : "star")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .help(app.isFavorite(pane.currentURL) ? L10n.tr("favorites.remove") : L10n.tr("favorites.add"))
            .accessibilityLabel(app.isFavorite(pane.currentURL) ? L10n.tr("favorites.remove") : L10n.tr("favorites.add"))

            ExplorerSortMenu(
                sortKey: pane.sortKey,
                sortAscending: pane.sortAscending,
                onSelectKey: { key in
                    pane.sortKey = key
                    onRefresh()
                },
                onToggleAscending: {
                    pane.sortAscending.toggle()
                    onRefresh()
                },
                borderless: true
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
    }

    @ViewBuilder
    private var content: some View {
        // Column view keeps its own chain; avoid unmounting it on every in-pane focus load.
        if pane.isLoading, pane.viewMode != .columns {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = pane.errorMessage, pane.viewMode != .columns || pane.items.isEmpty {
            ExplorerEmptyState(
                title: L10n.tr("state.error.title"),
                systemImage: "exclamationmark.triangle",
                message: error,
                actionTitle: L10n.tr("toolbar.refresh"),
                action: onRefresh
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contextMenu { backgroundMenu }
        } else if pane.viewMode == .columns {
            // Keep the column browser mounted even when the focused leaf is empty —
            // otherwise navigating into an empty folder replaces the whole chain with
            // the full-pane empty state (and looks like “losing” columns).
            FileColumnView(
                directoryURL: pane.currentURL,
                items: displayedItems,
                isFlat: showsSearchResults,
                sortKey: pane.sortKey,
                sortAscending: pane.sortAscending,
                selection: $pane.selectedURLs,
                onOpen: onOpen,
                onFocusDirectory: { url, urls in
                    if let onFocusDirectory {
                        onFocusDirectory(url, urls)
                    } else {
                        onOpen(FileItem.representingDirectory(url))
                    }
                },
                renameURL: renameURL,
                renameText: $renameText,
                onCommitRename: onCommitRename,
                onCancelRename: onCancelRename,
                itemMenu: { item in selectionMenu(urls: [item.url]) },
                backgroundMenu: { backgroundMenu }
            )
        } else if displayedItems.isEmpty {
            // Empty folder in-place (no “Open Folder” CTA) so New File / New Folder work via menu/toolbar.
            ExplorerEmptyState(
                title: L10n.tr("state.empty.title"),
                systemImage: "folder",
                message: L10n.tr("state.empty.message")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .contextMenu { backgroundMenu }
        } else if pane.viewMode == .grid {
            FileGridView(
                items: displayedItems,
                selection: $pane.selectedURLs,
                onOpen: onOpen,
                renameURL: renameURL,
                renameText: $renameText,
                onCommitRename: onCommitRename,
                onCancelRename: onCancelRename,
                itemMenu: { item in selectionMenu(urls: [item.url]) },
                backgroundMenu: { backgroundMenu }
            )
        } else {
            FileListView(
                items: displayedItems,
                selection: $pane.selectedURLs,
                directoryURL: pane.currentURL,
                sortKey: pane.sortKey,
                sortAscending: pane.sortAscending,
                onOpen: onOpen,
                onSortChange: { key, ascending in
                    pane.sortKey = key
                    pane.sortAscending = ascending
                    onRefresh()
                },
                renameURL: renameURL,
                renameText: $renameText,
                onCommitRename: onCommitRename,
                onCancelRename: onCancelRename,
                callbacks: menuCallbacks
            )
        }
    }

    @ViewBuilder
    private var backgroundMenu: some View {
        FileContextMenu(
            items: [],
            directoryURL: pane.currentURL,
            callbacks: menuCallbacks
        )
    }

    @ViewBuilder
    private func selectionMenu(urls: Set<URL>) -> some View {
        let selected = displayedItems.filter { urls.contains($0.url) }
        FileContextMenu(
            items: selected,
            directoryURL: pane.currentURL,
            callbacks: menuCallbacks
        )
    }

}

extension Notification.Name {
    static let explorerOpenFolder = Notification.Name("explorerOpenFolder")
}
