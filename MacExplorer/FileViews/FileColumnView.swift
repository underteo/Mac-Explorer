import AppKit
import SwiftUI

/// Finder-style column browser: each selected folder opens a column to the right.
struct FileColumnView<ItemMenu: View, BackgroundMenu: View>: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings

    /// Directory currently focused by the pane (rightmost directory column / creation target).
    let directoryURL: URL
    /// Items for `directoryURL` (and for flat search results).
    let items: [FileItem]
    /// When true, show a single flat column (search) instead of drilling.
    var isFlat: Bool = false
    let sortKey: FileSortKey
    let sortAscending: Bool
    @Binding var selection: Set<URL>
    let onOpen: (FileItem) -> Void
    /// In-pane focus when a folder is selected (does not honor “open folders in tabs”).
    let onFocusDirectory: (URL, Set<URL>) -> Void
    var renameURL: URL?
    @Binding var renameText: String
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    @ViewBuilder let itemMenu: (FileItem) -> ItemMenu
    @ViewBuilder let backgroundMenu: () -> BackgroundMenu

    @State private var columns: [ColumnModel] = []
    @State private var scrollToken = UUID()

    private let columnWidth: CGFloat = 200

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                        columnPane(index: index, column: column)
                            .frame(width: columnWidth)
                            .overlay(alignment: .trailing) {
                                Divider()
                            }
                            .id(column.id)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .onChange(of: scrollToken) { _, _ in
                if let last = columns.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last, anchor: .trailing)
                    }
                }
            }
        }
        .onAppear { syncColumnsFromPane(forceReset: columns.isEmpty) }
        .onChange(of: directoryURL) { _, _ in syncColumnsFromPane(forceReset: false) }
        .onChange(of: items) { _, _ in syncColumnsFromPane(forceReset: false) }
        .onChange(of: isFlat) { _, _ in syncColumnsFromPane(forceReset: true) }
        .onChange(of: sortKey) { _, _ in reloadAllColumns() }
        .onChange(of: sortAscending) { _, _ in reloadAllColumns() }
        .onChange(of: app.showHiddenFiles) { _, _ in reloadAllColumns() }
    }

    @ViewBuilder
    private func columnPane(index: Int, column: ColumnModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(column.items) { item in
                    columnRow(item: item, columnIndex: index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .contextMenu { backgroundMenu() }
    }

    @ViewBuilder
    private func columnRow(item: FileItem, columnIndex: Int) -> some View {
        let deepest = deepestSelectedURL
        let isPathSelected = columns.indices.contains(columnIndex)
            && columns[columnIndex].selectedChildURL == item.url
        let isLeafSelected = item.url == deepest
        let highlight: Color = {
            if isLeafSelected { return Color.accentColor }
            if isPathSelected { return Color.primary.opacity(0.12) }
            return .clear
        }()
        let listed = item.listedName(showExtension: settings.showAllFilenameExtensions)

        HStack(spacing: 6) {
            Image(nsImage: FileIconCache.icon(for: item.url, size: 16))
                .resizable()
                .frame(width: 16, height: 16)

            if renameURL == item.url {
                InlineRenameField(
                    text: $renameText,
                    isDirectory: item.isDirectory,
                    onCommit: onCommitRename,
                    onCancel: onCancelRename
                )
                .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            } else {
                Text(listed)
                    .lineLimit(1)
                    .foregroundStyle(isLeafSelected ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if item.isDirectory, !isFlat {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isLeafSelected ? Color.white.opacity(0.9) : Color.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(highlight)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard renameURL != item.url else { return }
            onOpen(item)
        }
        .onTapGesture {
            guard renameURL != item.url else { return }
            select(item, inColumn: columnIndex)
        }
        .contextMenu {
            Color.clear
                .frame(width: 0, height: 0)
                .onAppear {
                    if !selection.contains(item.url) {
                        selection = [item.url]
                    }
                }
            itemMenu(item)
        }
        .accessibilityLabel(listed)
    }

    private var deepestSelectedURL: URL? {
        if let selected = selection.first {
            return selected
        }
        return columns.reversed().compactMap(\.selectedChildURL).first
    }

    private func select(_ item: FileItem, inColumn columnIndex: Int) {
        guard columns.indices.contains(columnIndex) else { return }

        var next = Array(columns.prefix(columnIndex + 1))
        next[columnIndex].selectedChildURL = item.url
        selection = [item.url]

        if item.isDirectory, !isFlat {
            Task { await expandDirectory(item.url, after: next) }
        } else {
            columns = next
            let parent = next[columnIndex].directoryURL
            onFocusDirectory(parent, [item.url])
        }
    }

    @MainActor
    private func expandDirectory(_ url: URL, after prefix: [ColumnModel]) async {
        let children: [FileItem]
        do {
            children = try loadItems(of: url)
        } catch {
            app.lastErrorMessage = error.localizedDescription
            columns = prefix
            return
        }

        var next = prefix
        next.append(ColumnModel(directoryURL: url, items: children, selectedChildURL: nil))
        columns = next
        scrollToken = UUID()
        onFocusDirectory(url, [url])
    }

    private func syncColumnsFromPane(forceReset: Bool) {
        let focused = directoryURL.standardizedFileURL

        if isFlat {
            columns = [
                ColumnModel(
                    directoryURL: focused,
                    items: items,
                    selectedChildURL: selection.first
                )
            ]
            return
        }

        if forceReset || columns.isEmpty {
            columns = [
                ColumnModel(
                    directoryURL: focused,
                    items: items,
                    selectedChildURL: selection.first
                )
            ]
            return
        }

        if let idx = columns.firstIndex(where: { $0.directoryURL.standardizedFileURL == focused }) {
            var next = Array(columns.prefix(idx + 1))
            next[idx].items = items
            // Preserve path selection into this column when still valid.
            if idx > 0 {
                let parentSelected = next[idx - 1].selectedChildURL?.standardizedFileURL
                if parentSelected != focused {
                    next[idx - 1].selectedChildURL = focused
                }
            }
            columns = next
            return
        }

        if let last = columns.last,
           focused.path.hasPrefix(last.directoryURL.standardizedFileURL.path + "/") {
            // Deeper navigation from outside (e.g. path bar) — reset to a single focused column.
            columns = [
                ColumnModel(directoryURL: focused, items: items, selectedChildURL: selection.first)
            ]
            scrollToken = UUID()
            return
        }

        columns = [
            ColumnModel(directoryURL: focused, items: items, selectedChildURL: selection.first)
        ]
        scrollToken = UUID()
    }

    private func reloadAllColumns() {
        guard !isFlat else {
            columns = [ColumnModel(directoryURL: directoryURL, items: items, selectedChildURL: selection.first)]
            return
        }
        Task { @MainActor in
            var rebuilt: [ColumnModel] = []
            for column in columns {
                do {
                    let listed = try loadItems(of: column.directoryURL)
                    rebuilt.append(
                        ColumnModel(
                            directoryURL: column.directoryURL,
                            items: listed,
                            selectedChildURL: column.selectedChildURL
                        )
                    )
                } catch {
                    app.lastErrorMessage = error.localizedDescription
                    break
                }
            }
            if !rebuilt.isEmpty {
                columns = rebuilt
            }
        }
    }

    private func loadItems(of url: URL) throws -> [FileItem] {
        var listing = app.filesystem
        listing.includeHiddenFiles = app.showHiddenFiles
        return try listing.listContents(
            of: url,
            sortKey: sortKey,
            ascending: sortAscending,
            keepFoldersOnTop: settings.keepFoldersOnTop(directory: url, sortKey: sortKey)
        )
    }
}

private struct ColumnModel: Identifiable, Equatable {
    var id: URL { directoryURL }
    var directoryURL: URL
    var items: [FileItem]
    var selectedChildURL: URL?
}
