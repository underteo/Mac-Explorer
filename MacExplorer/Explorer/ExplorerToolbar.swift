import AppKit
import SwiftUI

/// Window toolbar — fixed membership so capsules never appear/disappear
/// (dual-pane transfer, empty trash, view/sort). Unavailable actions are disabled.
struct ExplorerToolbar: ToolbarContent {
    @EnvironmentObject private var app: AppModel

    let onGoBack: () -> Void
    let onGoForward: () -> Void
    let onGoUp: () -> Void
    let onOpenFolder: () -> Void
    let onNewFolder: () -> Void
    let onRefresh: () -> Void
    let onEmptyTrash: () -> Void
    let onHiddenFilesChanged: () -> Void
    let onDualPaneEnabled: () -> Void
    let onCopyToOtherPane: () -> Void
    let onMoveToOtherPane: () -> Void
    let onToggleFavorite: () -> Void
    let onSortKey: (FileSortKey) -> Void
    let onToggleSortAscending: () -> Void

    private var isInTrash: Bool {
        FileItem.isTrashURL(app.activePane.currentURL)
    }

    private var transferEnabled: Bool {
        app.dualPaneEnabled && !app.activePane.selectedURLs.isEmpty
    }

    private var favoriteURL: URL {
        app.activePane.currentURL
    }

    private var isFavorite: Bool {
        app.isFavorite(favoriteURL)
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: onGoBack) {
                Image(systemName: "chevron.backward")
            }
            .disabled(!app.primaryPane.history.canGoBack)
            .help(L10n.tr("command.back"))
            .accessibilityLabel(L10n.tr("command.back"))

            Button(action: onGoForward) {
                Image(systemName: "chevron.forward")
            }
            .disabled(!app.primaryPane.history.canGoForward)
            .help(L10n.tr("command.forward"))
            .accessibilityLabel(L10n.tr("command.forward"))

            Button(action: onGoUp) {
                Image(systemName: "chevron.up")
            }
            .disabled(app.primaryPane.currentURL.path == "/")
            .help(L10n.tr("command.enclosing_folder"))
            .accessibilityLabel(L10n.tr("command.enclosing_folder"))
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onOpenFolder) {
                Label(L10n.tr("toolbar.open_folder"), systemImage: "folder.badge.plus")
            }
            .help(L10n.tr("toolbar.open_folder"))
            .accessibilityLabel(L10n.tr("toolbar.open_folder"))

            Button(action: onNewFolder) {
                Label(L10n.tr("action.new_folder"), systemImage: "plus.rectangle.on.folder")
            }
            .help(L10n.tr("action.new_folder"))
            .accessibilityLabel(L10n.tr("action.new_folder"))

            Button(action: onRefresh) {
                Label(L10n.tr("toolbar.refresh"), systemImage: "arrow.clockwise")
            }
            .help(L10n.tr("toolbar.refresh"))
            .accessibilityLabel(L10n.tr("toolbar.refresh"))

            Button(action: onEmptyTrash) {
                Label(L10n.tr("action.empty_trash"), systemImage: "trash.slash")
            }
            .disabled(!isInTrash)
            .help(L10n.tr("action.empty_trash"))
            .accessibilityLabel(L10n.tr("action.empty_trash"))

            Toggle(isOn: $app.showHiddenFiles) {
                Image(systemName: "eye")
            }
            .toggleStyle(.button)
            .help(L10n.tr("command.toggle_hidden"))
            .accessibilityLabel(L10n.tr("command.toggle_hidden"))
            .onChange(of: app.showHiddenFiles) { _, _ in
                onHiddenFilesChanged()
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            ExplorerViewModePicker(viewMode: activeViewModeBinding)

            ExplorerSortMenu(
                sortKey: app.activePane.sortKey,
                sortAscending: app.activePane.sortAscending,
                onSelectKey: onSortKey,
                onToggleAscending: onToggleSortAscending
            )

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
            }
            .help(isFavorite ? L10n.tr("favorites.remove") : L10n.tr("favorites.add"))
            .accessibilityLabel(isFavorite ? L10n.tr("favorites.remove") : L10n.tr("favorites.add"))
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Toggle(isOn: $app.dualPaneEnabled) {
                Image(systemName: "rectangle.split.2x1")
            }
            .toggleStyle(.button)
            .help(L10n.tr("toolbar.dual_pane"))
            .accessibilityLabel(L10n.tr("toolbar.dual_pane"))
            .onChange(of: app.dualPaneEnabled) { _, enabled in
                if enabled { onDualPaneEnabled() }
            }

            // Always present — disabled when single-pane or nothing selected.
            Button(action: onCopyToOtherPane) {
                Label(L10n.tr("toolbar.copy_to_other"), systemImage: "doc.on.doc")
            }
            .disabled(!transferEnabled)
            .help(L10n.tr("toolbar.copy_to_other"))
            .accessibilityLabel(L10n.tr("toolbar.copy_to_other"))

            Button(action: onMoveToOtherPane) {
                Label(L10n.tr("toolbar.move_to_other"), systemImage: "arrow.right.doc.on.clipboard")
            }
            .disabled(!transferEnabled)
            .help(L10n.tr("toolbar.move_to_other"))
            .accessibilityLabel(L10n.tr("toolbar.move_to_other"))
        }
    }

    private var activeViewModeBinding: Binding<FileViewMode> {
        Binding(
            get: { app.activePane.viewMode },
            set: { mode in
                if app.activePaneID == .secondary, app.dualPaneEnabled {
                    var pane = app.secondaryPane
                    pane.viewMode = mode
                    app.secondaryPane = pane
                } else {
                    var pane = app.primaryPane
                    pane.viewMode = mode
                    app.primaryPane = pane
                }
            }
        )
    }
}

/// Share / Tags / More — lives beside the path bar (not in the window toolbar)
/// so selection actions never reshuffle with view/sort capsules.
struct ExplorerSelectionActionsBar: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings

    let selectedURLs: [URL]
    let tagsPopoverTitle: String
    @Binding var showTagsPopover: Bool
    @Binding var showMorePopover: Bool
    let onShare: () -> Void
    let onRefresh: () -> Void
    let onNewFolder: () -> Void
    let onCompress: () -> Void
    let onMakeAlias: () -> Void
    let onQuickLook: () -> Void

    private var hasSelection: Bool { !selectedURLs.isEmpty }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(!hasSelection)
            .help(L10n.tr("toolbar.share"))
            .accessibilityLabel(L10n.tr("toolbar.share"))

            Button {
                showTagsPopover.toggle()
            } label: {
                Image(systemName: "tag")
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(!hasSelection)
            .help(L10n.tr("action.tags"))
            .accessibilityLabel(L10n.tr("action.tags"))
            .popover(isPresented: $showTagsPopover, arrowEdge: .bottom) {
                FinderTagsAssignPopover(
                    urls: selectedURLs,
                    title: tagsPopoverTitle,
                    onChanged: onRefresh
                )
            }

            Button {
                showMorePopover.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("toolbar.more"))
            .accessibilityLabel(L10n.tr("toolbar.more"))
            .popover(isPresented: $showMorePopover, arrowEdge: .bottom) {
                ToolbarMoreActionsPopover(
                    hasSelection: hasSelection,
                    compressTitle: FileMenuActions.compressTitle(for: app.activePane.selectedItems),
                    onNewFolder: {
                        showMorePopover = false
                        onNewFolder()
                    },
                    onGetInfo: {
                        showMorePopover = false
                        FileMenuActions.getInfo(app.activePane.selectedItems, app: app)
                    },
                    onDuplicate: {
                        showMorePopover = false
                        FileMenuActions.duplicate(
                            app.activePane.selectedItems,
                            app: app,
                            onRefresh: onRefresh
                        )
                    },
                    onCompress: {
                        showMorePopover = false
                        onCompress()
                    },
                    onMakeAlias: {
                        showMorePopover = false
                        onMakeAlias()
                    },
                    onQuickLook: {
                        showMorePopover = false
                        onQuickLook()
                    },
                    onCopy: {
                        showMorePopover = false
                        FileMenuActions.copy(app.activePane.selectedItems, app: app)
                    },
                    onCopyPath: {
                        showMorePopover = false
                        FileMenuActions.copyPath(app.activePane.selectedItems, app: app)
                    },
                    onSettings: {
                        showMorePopover = false
                        settings.openSettings(tab: .general)
                    }
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(.quaternary.opacity(0.45), in: Capsule())
        .overlay {
            Capsule().strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.tr("toolbar.selection_actions"))
    }
}

struct ExplorerViewModePicker: View {
    @Binding var viewMode: FileViewMode
    var compact: Bool = false

    var body: some View {
        Picker(L10n.tr("toolbar.view"), selection: $viewMode) {
            Image(systemName: "square.grid.2x2").tag(FileViewMode.grid)
            Image(systemName: "list.bullet").tag(FileViewMode.list)
            Image(systemName: "rectangle.split.3x1").tag(FileViewMode.columns)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(compact ? .small : .regular)
        .frame(maxWidth: compact ? 118 : nil)
        .help(L10n.tr("toolbar.view"))
        .accessibilityLabel(L10n.tr("toolbar.view"))
    }
}

struct ExplorerSortMenu: View {
    let sortKey: FileSortKey
    let sortAscending: Bool
    let onSelectKey: (FileSortKey) -> Void
    let onToggleAscending: () -> Void
    var borderless: Bool = false

    var body: some View {
        Menu {
            ForEach(FileSortKey.allCases) { key in
                Button {
                    onSelectKey(key)
                } label: {
                    if sortKey == key {
                        Label(L10n.tr("sort.\(key.rawValue)"), systemImage: "checkmark")
                    } else {
                        Text(L10n.tr("sort.\(key.rawValue)"))
                    }
                }
            }
            Divider()
            Button(action: onToggleAscending) {
                Text(sortAscending ? L10n.tr("sort.descending") : L10n.tr("sort.ascending"))
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(.primary)
        }
        .menuIndicator(.hidden)
        .modifier(OptionalBorderlessMenu(enabled: borderless))
        .help(L10n.tr("toolbar.sort"))
        .accessibilityLabel(L10n.tr("toolbar.sort"))
    }
}

private struct OptionalBorderlessMenu: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.menuStyle(.borderlessButton)
        } else {
            content
        }
    }
}
