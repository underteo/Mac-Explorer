import Foundation

/// Pane-specific hooks so SwiftUI and AppKit menus stay in sync without duplicating logic.
struct FileMenuCallbacks {
    var onRename: (FileItem) -> Void
    var onTrash: () -> Void
    var onRefresh: () -> Void
    var onCreated: (URL) -> Void
    var onPaste: () -> Void
    /// Open folder (or file’s parent) in the other dual pane.
    var onOpenInNewPane: (URL) -> Void
    var onSort: (FileSortKey) -> Void
    var onShowViewOptions: () -> Void
}
