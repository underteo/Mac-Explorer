import SwiftUI
import AppKit

/// Right-click menu — only actions whose placement is `.context` (see Settings → Menu).
struct FileContextMenu: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    let items: [FileItem]
    let directoryURL: URL
    let callbacks: FileMenuCallbacks

    private func show(_ action: ContextMenuActionID) -> Bool {
        settings.showsInContextMenu(action)
    }

    var body: some View {
        Group {
            if !items.isEmpty, show(.open) {
                Button(L10n.tr("action.open")) {
                    FileMenuActions.open(items, app: app)
                }
            }
            if show(.openWith) { openWithSection }

            if show(.newFolder) {
                Button(L10n.tr("action.new_folder")) {
                    FileMenuActions.newFolder(in: directoryURL, app: app, onCreated: callbacks.onCreated)
                }
            }
            if show(.newFile) {
                Menu(L10n.tr("action.new_file")) {
                    ForEach(FileTemplate.allCases) { template in
                        Button(template.displayName) {
                            FileMenuActions.newFile(
                                template: template,
                                in: directoryURL,
                                app: app,
                                onCreated: callbacks.onCreated
                            )
                        }
                    }
                }
            }
            if show(.newTextFile) {
                Button(L10n.tr("action.new_text_file")) {
                    FileMenuActions.newFile(
                        template: .txt,
                        in: directoryURL,
                        app: app,
                        onCreated: callbacks.onCreated
                    )
                }
            }
            if show(.openInNewPane) {
                Button(L10n.tr("action.open_in_new_pane")) {
                    FileMenuActions.openInNewPane(
                        items: items,
                        directoryURL: directoryURL,
                        callbacks: callbacks
                    )
                }
            }

            if !items.isEmpty, items.count == 1, show(.rename), let item = items.first {
                Button(L10n.tr("action.rename")) { callbacks.onRename(item) }
            }

            if !items.isEmpty {
                if show(.copy) {
                    Button(L10n.tr("action.copy")) { FileMenuActions.copy(items, app: app) }
                }
                if show(.cut) {
                    Button(L10n.tr("action.cut")) { FileMenuActions.cut(items, app: app) }
                }
                if show(.duplicate) {
                    Button(L10n.tr("action.duplicate")) {
                        FileMenuActions.duplicate(items, app: app, onRefresh: callbacks.onRefresh)
                    }
                }
                if show(.compress) {
                    Button(FileMenuActions.compressTitle(for: items)) {
                        FileMenuActions.compress(items, app: app, onRefresh: callbacks.onRefresh)
                    }
                }
                if show(.makeAlias) {
                    Button(L10n.tr("action.make_alias")) {
                        FileMenuActions.makeAlias(items, app: app, onRefresh: callbacks.onRefresh)
                    }
                }
                if show(.quickLook) {
                    Button(L10n.tr("action.quick_look")) { FileMenuActions.quickLook(items) }
                }
                if show(.copyPath) {
                    Button(L10n.tr("action.copy_path")) { FileMenuActions.copyPath(items, app: app) }
                }
                if show(.getInfo) {
                    Button(L10n.tr("action.get_info")) { FileMenuActions.getInfo(items, app: app) }
                }
                if show(.revealInFinder) {
                    Button(L10n.tr("action.reveal_finder")) {
                        FileMenuActions.revealInFinder(items, app: app)
                    }
                }
            }

            if show(.paste), app.fileClipboard != nil {
                Button(L10n.tr("action.paste")) {
                    FileMenuActions.paste(app: app, onPaste: callbacks.onPaste)
                }
            }

            if !items.isEmpty, show(.tags) {
                Divider()
                tagSection
                // Finder layout: color dots, then “Personalizza cartella…” with tag icon.
                Button {
                    FileMenuActions.customizeInFinder(items, directoryURL: directoryURL)
                } label: {
                    Label(L10n.tr("action.customize_folder"), systemImage: "tag")
                }
                Divider()
            } else if show(.customizeInFinder) {
                Button {
                    FileMenuActions.customizeInFinder(items, directoryURL: directoryURL)
                } label: {
                    Label(L10n.tr("action.customize_folder"), systemImage: "tag")
                }
            }
            if show(.sortBy) { sortSection }
            if show(.showViewOptions) {
                Button(L10n.tr("action.show_view_options")) { callbacks.onShowViewOptions() }
            }
            if show(.folderActionsSetup) {
                Button(L10n.tr("action.folder_actions_setup")) {
                    app.fileOperations.openFolderActionsSetup()
                }
            }
            if show(.terminalTab) {
                Button(L10n.tr("action.terminal_tab")) {
                    FileMenuActions.openTerminal(at: directoryURL, newTab: true, items: items, app: app)
                }
            }
            if show(.terminalWindow) {
                Button(L10n.tr("action.terminal_window")) {
                    FileMenuActions.openTerminal(at: directoryURL, newTab: false, items: items, app: app)
                }
            }

            if show(.favorites) { favoritesSection }
            if show(.plugins) { pluginSection }

            if !items.isEmpty, show(.trash) {
                Divider()
                Button(L10n.tr("action.move_to_trash"), role: .destructive) {
                    callbacks.onTrash()
                }
            }

            // Always available — shortcut to visibility settings for this menu.
            Divider()
            Button(L10n.tr("action.menu_settings")) {
                settings.openSettings(tab: .menu)
            }
        }
    }

    @ViewBuilder
    private var tagSection: some View {
        FinderTagDotsRow(selectedColors: selectedTagColors) { color in
            FileMenuActions.toggleTag(color, items: items, app: app, onRefresh: callbacks.onRefresh)
        }
    }

    private var selectedTagColors: Set<FinderColorTag> {
        var set = Set<FinderColorTag>()
        for item in items {
            for color in FinderColorTag.allCases where FinderTags.isOn(color, for: item.url)
                || item.finderColorTags.contains(color) {
                set.insert(color)
            }
        }
        return set
    }

    @ViewBuilder
    private var sortSection: some View {
        Menu(L10n.tr("action.sort_by")) {
            ForEach(FileSortKey.allCases) { key in
                Button(L10n.tr("sort.\(key.rawValue)")) { callbacks.onSort(key) }
            }
        }
    }

    @ViewBuilder
    private var openWithSection: some View {
        if items.count == 1, let item = items.first, !item.isDirectory {
            Menu(L10n.tr("action.open_with")) {
                ForEach(app.openWith.applications(for: item.url)) { candidate in
                    Button(candidate.name) {
                        try? app.openWith.open(item.url, with: candidate.url)
                    }
                }
                Divider()
                Button(L10n.tr("open_with.other")) {
                    app.openWith.openWithPanel(for: item.url)
                }
            }
        }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        let url = FileMenuActions.favoriteURL(items: items, directoryURL: directoryURL)
        if app.isFavorite(url) {
            Button(L10n.tr("favorites.remove")) { app.removeFavorite(url: url) }
        } else {
            Button(L10n.tr("favorites.add")) { _ = app.addFavorite(url) }
        }
    }

    @ViewBuilder
    private var pluginSection: some View {
        let pluginItems = PluginMenuTargets.resolve(selected: items, directoryURL: directoryURL)
        let plugins = app.pluginManager.enabledMenuProviders(for: pluginItems)
        ForEach(plugins) { plugin in
            Menu(L10n.tr(plugin.manifest.name)) {
                PluginMenuContent(nodes: plugin.manifest.menu) { action in
                    let result = app.pluginManager.run(action: action, plugin: plugin, items: pluginItems)
                    if case .failure(let error) = result {
                        app.lastErrorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

private struct PluginMenuContent: View {
    let nodes: [PluginMenuNode]
    let onAction: (PluginMenuAction) -> Void

    var body: some View {
        ForEach(nodes) { node in
            switch node {
            case .action(let action):
                Button(L10n.tr(action.title)) { onAction(action) }
            case .submenu(let title, let children):
                Menu(L10n.tr(title)) {
                    PluginMenuContent(nodes: children, onAction: onAction)
                }
            }
        }
    }
}
