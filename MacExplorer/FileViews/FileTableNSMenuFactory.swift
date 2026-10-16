import AppKit
import ObjectiveC

/// AppKit context menu for the list view — mirrors `FileContextMenu` using the same placements.
@MainActor
enum FileTableNSMenuFactory {
    static func make(
        urls: Set<URL>,
        items: [FileItem],
        directoryURL: URL,
        app: AppModel,
        settings: AppSettings,
        callbacks: FileMenuCallbacks
    ) -> NSMenu {
        let menu = NSMenu()
        let selected = items.filter { urls.contains($0.url) }

        func show(_ action: ContextMenuActionID) -> Bool {
            settings.showsInContextMenu(action)
        }

        if !selected.isEmpty, show(.open) {
            add(menu, L10n.tr("action.open")) {
                FileMenuActions.open(selected, app: app)
            }
        }

        if show(.openWith), selected.count == 1, let item = selected.first, !item.isDirectory {
            let openWith = NSMenuItem(title: L10n.tr("action.open_with"), action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for candidate in app.openWith.applications(for: item.url) {
                add(sub, candidate.name) {
                    try? app.openWith.open(item.url, with: candidate.url)
                }
            }
            sub.addItem(.separator())
            add(sub, L10n.tr("open_with.other")) {
                app.openWith.openWithPanel(for: item.url)
            }
            openWith.submenu = sub
            menu.addItem(openWith)
        }

        if show(.newFolder) {
            add(menu, L10n.tr("action.new_folder")) {
                FileMenuActions.newFolder(in: directoryURL, app: app, onCreated: callbacks.onCreated)
            }
        }

        if show(.newFile) {
            let newFile = NSMenuItem(title: L10n.tr("action.new_file"), action: nil, keyEquivalent: "")
            let fileMenu = NSMenu()
            for template in FileTemplate.allCases {
                add(fileMenu, template.displayName) {
                    FileMenuActions.newFile(
                        template: template,
                        in: directoryURL,
                        app: app,
                        onCreated: callbacks.onCreated
                    )
                }
            }
            newFile.submenu = fileMenu
            menu.addItem(newFile)
        }

        if show(.newTextFile) {
            add(menu, L10n.tr("action.new_text_file")) {
                FileMenuActions.newFile(
                    template: .txt,
                    in: directoryURL,
                    app: app,
                    onCreated: callbacks.onCreated
                )
            }
        }

        if show(.openInNewPane) {
            add(menu, L10n.tr("action.open_in_new_pane")) {
                FileMenuActions.openInNewPane(
                    items: selected,
                    directoryURL: directoryURL,
                    callbacks: callbacks
                )
            }
        }

        if selected.count == 1, show(.rename), let item = selected.first {
            add(menu, L10n.tr("action.rename")) { callbacks.onRename(item) }
        }

        if !selected.isEmpty {
            if show(.copy) {
                add(menu, L10n.tr("action.copy")) { FileMenuActions.copy(selected, app: app) }
            }
            if show(.cut) {
                add(menu, L10n.tr("action.cut")) { FileMenuActions.cut(selected, app: app) }
            }
            if show(.duplicate) {
                add(menu, L10n.tr("action.duplicate")) {
                    FileMenuActions.duplicate(selected, app: app, onRefresh: callbacks.onRefresh)
                }
            }
            if show(.compress) {
                add(menu, FileMenuActions.compressTitle(for: selected)) {
                    FileMenuActions.compress(selected, app: app, onRefresh: callbacks.onRefresh)
                }
            }
            if show(.makeAlias) {
                add(menu, L10n.tr("action.make_alias")) {
                    FileMenuActions.makeAlias(selected, app: app, onRefresh: callbacks.onRefresh)
                }
            }
            if show(.quickLook) {
                add(menu, L10n.tr("action.quick_look")) { FileMenuActions.quickLook(selected) }
            }
            if show(.copyPath) {
                add(menu, L10n.tr("action.copy_path")) { FileMenuActions.copyPath(selected, app: app) }
            }
            if show(.getInfo) {
                add(menu, L10n.tr("action.get_info")) { FileMenuActions.getInfo(selected, app: app) }
            }
            if show(.revealInFinder) {
                add(menu, L10n.tr("action.reveal_finder")) {
                    FileMenuActions.revealInFinder(selected, app: app)
                }
            }
        }

        if show(.paste), app.fileClipboard != nil {
            add(menu, L10n.tr("action.paste"), callbacks.onPaste)
        }

        if !selected.isEmpty, show(.tags) {
            menu.addItem(.separator())
            var onColors = Set<FinderColorTag>()
            for item in selected {
                for color in FinderColorTag.allCases where FinderTags.isOn(color, for: item.url) {
                    onColors.insert(color)
                }
            }
            let dotsItem = NSMenuItem()
            let dotsView = FinderTagDotsMenuView(selected: onColors) { color in
                FileMenuActions.toggleTag(color, items: selected, app: app, onRefresh: callbacks.onRefresh)
            }
            dotsItem.view = dotsView
            menu.addItem(dotsItem)

            let customize = NSMenuItem(
                title: L10n.tr("action.customize_folder"),
                action: #selector(MenuActionProxy.invoke(_:)),
                keyEquivalent: ""
            )
            customize.image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
            let customizeProxy = MenuActionProxy {
                FileMenuActions.customizeInFinder(selected, directoryURL: directoryURL)
            }
            customize.target = customizeProxy
            objc_setAssociatedObject(customize, &menuActionProxyKey, customizeProxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            menu.addItem(customize)
            menu.addItem(.separator())
        } else if show(.customizeInFinder) {
            let customize = NSMenuItem(
                title: L10n.tr("action.customize_folder"),
                action: #selector(MenuActionProxy.invoke(_:)),
                keyEquivalent: ""
            )
            customize.image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
            let customizeProxy = MenuActionProxy {
                FileMenuActions.customizeInFinder(selected, directoryURL: directoryURL)
            }
            customize.target = customizeProxy
            objc_setAssociatedObject(customize, &menuActionProxyKey, customizeProxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            menu.addItem(customize)
        }

        if show(.sortBy) {
            let sortItem = NSMenuItem(title: L10n.tr("action.sort_by"), action: nil, keyEquivalent: "")
            let sortMenu = NSMenu()
            for key in FileSortKey.allCases {
                add(sortMenu, L10n.tr("sort.\(key.rawValue)")) { callbacks.onSort(key) }
            }
            sortItem.submenu = sortMenu
            menu.addItem(sortItem)
        }

        if show(.showViewOptions) {
            add(menu, L10n.tr("action.show_view_options"), callbacks.onShowViewOptions)
        }
        if show(.folderActionsSetup) {
            add(menu, L10n.tr("action.folder_actions_setup")) {
                app.fileOperations.openFolderActionsSetup()
            }
        }
        if show(.terminalTab) {
            add(menu, L10n.tr("action.terminal_tab")) {
                FileMenuActions.openTerminal(at: directoryURL, newTab: true, items: selected, app: app)
            }
        }
        if show(.terminalWindow) {
            add(menu, L10n.tr("action.terminal_window")) {
                FileMenuActions.openTerminal(at: directoryURL, newTab: false, items: selected, app: app)
            }
        }

        if show(.favorites) {
            menu.addItem(.separator())
            let favURL = FileMenuActions.favoriteURL(items: selected, directoryURL: directoryURL)
            let favTitle = app.isFavorite(favURL) ? L10n.tr("favorites.remove") : L10n.tr("favorites.add")
            add(menu, favTitle) {
                if app.isFavorite(favURL) {
                    app.removeFavorite(url: favURL)
                } else {
                    _ = app.addFavorite(favURL)
                }
            }
        }

        if show(.plugins) {
            let pluginItems = PluginMenuTargets.resolve(selected: selected, directoryURL: directoryURL)
            let plugins = app.pluginManager.enabledMenuProviders(for: pluginItems)
            if !plugins.isEmpty {
                menu.addItem(.separator())
                for plugin in plugins {
                    let root = NSMenuItem(title: L10n.tr(plugin.manifest.name), action: nil, keyEquivalent: "")
                    let submenu = NSMenu()
                    appendPluginNodes(
                        plugin.manifest.menu,
                        to: submenu,
                        plugin: plugin,
                        items: pluginItems,
                        app: app
                    )
                    root.submenu = submenu
                    menu.addItem(root)
                }
            }
        }

        if !selected.isEmpty, show(.trash) {
            menu.addItem(.separator())
            add(menu, L10n.tr("action.move_to_trash"), callbacks.onTrash)
        }

        // Always available — shortcut to visibility settings for this menu.
        menu.addItem(.separator())
        add(menu, L10n.tr("action.menu_settings")) {
            settings.openSettings(tab: .menu)
        }

        return menu
    }

    private static func appendPluginNodes(
        _ nodes: [PluginMenuNode],
        to menu: NSMenu,
        plugin: LoadedPlugin,
        items: [FileItem],
        app: AppModel
    ) {
        for node in nodes {
            switch node {
            case .action(let action):
                add(menu, L10n.tr(action.title)) {
                    let result = app.pluginManager.run(action: action, plugin: plugin, items: items)
                    if case .failure(let error) = result {
                        app.lastErrorMessage = error.localizedDescription
                    }
                }
            case .submenu(let title, let children):
                let item = NSMenuItem(title: L10n.tr(title), action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                appendPluginNodes(children, to: submenu, plugin: plugin, items: items, app: app)
                item.submenu = submenu
                menu.addItem(item)
            }
        }
    }

    private static func add(_ menu: NSMenu, _ title: String, _ action: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: #selector(MenuActionProxy.invoke(_:)), keyEquivalent: "")
        let proxy = MenuActionProxy(action)
        item.target = proxy
        objc_setAssociatedObject(item, &menuActionProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        menu.addItem(item)
    }
}

private nonisolated(unsafe) var menuActionProxyKey: UInt8 = 0

private final class MenuActionProxy: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func invoke(_ sender: Any?) { action() }
}
