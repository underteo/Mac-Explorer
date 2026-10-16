import SwiftUI
import AppKit

/// Row-based file list. Uses a native `NSTableView` so selection highlight matches Finder timing.
struct FileListView: View {
    @EnvironmentObject private var app: AppModel
    let items: [FileItem]
    @Binding var selection: Set<URL>
    let directoryURL: URL
    let onOpen: (FileItem) -> Void
    var renameURL: URL?
    @Binding var renameText: String
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    var onRename: (FileItem) -> Void
    var onTrash: () -> Void
    var onRefresh: () -> Void
    var onCreated: (URL) -> Void
    var onPaste: () -> Void

    var body: some View {
        NativeFileTableView(
            items: items,
            selection: $selection,
            renameURL: renameURL,
            renameText: $renameText,
            onOpen: onOpen,
            onCommitRename: onCommitRename,
            onCancelRename: onCancelRename,
            makeContextMenu: { urls in
                FileTableNSMenuFactory.make(
                    urls: urls,
                    items: items,
                    directoryURL: directoryURL,
                    app: app,
                    onRename: onRename,
                    onTrash: onTrash,
                    onRefresh: onRefresh,
                    onCreated: onCreated,
                    onPaste: onPaste
                )
            }
        )
    }
}
