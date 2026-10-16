import SwiftUI
import AppKit

/// Row-based file list with Finder-like folder expansion (outline).
struct FileListView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    let items: [FileItem]
    @Binding var selection: Set<URL>
    let directoryURL: URL
    var sortKey: FileSortKey = .name
    var sortAscending: Bool = true
    let onOpen: (FileItem) -> Void
    var renameURL: URL?
    @Binding var renameText: String
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    var callbacks: FileMenuCallbacks

    var body: some View {
        NativeFileTableView(
            items: items,
            sortKey: sortKey,
            sortAscending: sortAscending,
            keepFoldersOnTop: settings.keepFoldersOnTop(directory: directoryURL, sortKey: sortKey),
            includeHiddenFiles: app.showHiddenFiles,
            selection: $selection,
            renameURL: renameURL,
            renameText: $renameText,
            showFilenameExtensions: settings.showAllFilenameExtensions,
            onOpen: onOpen,
            onCommitRename: onCommitRename,
            onCancelRename: onCancelRename,
            makeContextMenu: { urls in
                FileTableNSMenuFactory.make(
                    urls: urls,
                    items: items,
                    directoryURL: directoryURL,
                    app: app,
                    settings: settings,
                    callbacks: callbacks
                )
            }
        )
    }
}
