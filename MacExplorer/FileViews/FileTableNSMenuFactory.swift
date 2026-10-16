import AppKit
import ObjectiveC

/// Builds AppKit context menus for the native file table (keeps SwiftUI out of the click path).
@MainActor
enum FileTableNSMenuFactory {
    static func make(
        urls: Set<URL>,
        items: [FileItem],
        directoryURL: URL,
        app: AppModel,
        onRename: @escaping (FileItem) -> Void,
        onTrash: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onCreated: @escaping (URL) -> Void,
        onPaste: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        let selected = items.filter { urls.contains($0.url) }

        if !selected.isEmpty {
            add(menu, L10n.tr("action.open")) {
                selected.forEach { app.fileOperations.open($0.url) }
            }
            menu.addItem(.separator())
        }

        add(menu, L10n.tr("action.new_folder")) {
            do {
                let url = try app.fileOperations.createFolder(
                    named: L10n.tr("default.new_folder"),
                    in: directoryURL
                )
                onCreated(url)
            } catch {
                app.lastErrorMessage = error.localizedDescription
            }
        }

        let newFile = NSMenuItem(title: L10n.tr("action.new_file"), action: nil, keyEquivalent: "")
        let fileMenu = NSMenu()
        for template in FileTemplate.allCases {
            add(fileMenu, template.displayName) {
                do {
                    let url = try app.fileOperations.createFile(template: template, in: directoryURL)
                    onCreated(url)
                } catch {
                    app.lastErrorMessage = error.localizedDescription
                }
            }
        }
        newFile.submenu = fileMenu
        menu.addItem(newFile)

        if selected.count == 1, let item = selected.first {
            add(menu, L10n.tr("action.rename")) { onRename(item) }
        }

        if !selected.isEmpty {
            add(menu, L10n.tr("action.copy")) {
                app.copyToClipboard(selected.map(\.url), cut: false)
            }
            add(menu, L10n.tr("action.cut")) {
                app.copyToClipboard(selected.map(\.url), cut: true)
            }
            add(menu, L10n.tr("action.duplicate")) {
                do {
                    for item in selected {
                        _ = try app.fileOperations.duplicate(item.url)
                    }
                    onRefresh()
                } catch {
                    app.lastErrorMessage = error.localizedDescription
                }
            }
            add(menu, L10n.tr("action.copy_path")) {
                app.fileOperations.copyPathToPasteboard(selected.map(\.url))
            }
            add(menu, L10n.tr("action.get_info")) {
                if let first = selected.first {
                    do {
                        app.infoSummary = try app.fileOperations.makeInfo(for: first.url)
                    } catch {
                        app.lastErrorMessage = error.localizedDescription
                    }
                }
            }
            add(menu, L10n.tr("action.reveal_finder")) {
                app.fileOperations.revealInFinder(selected.map(\.url))
            }
        }

        if app.fileClipboard != nil {
            add(menu, L10n.tr("action.paste"), onPaste)
        }

        menu.addItem(.separator())

        let favURL = selected.count == 1 && selected[0].isDirectory ? selected[0].url : directoryURL
        let favTitle = app.isFavorite(favURL) ? L10n.tr("favorites.remove") : L10n.tr("favorites.add")
        add(menu, favTitle) {
            if app.isFavorite(favURL) {
                app.removeFavorite(url: favURL)
            } else {
                _ = app.addFavorite(favURL)
            }
        }

        // Empty area → current folder so plugins (e.g. Cursor chat) can use the pane directory.
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

        if !selected.isEmpty {
            menu.addItem(.separator())
            let trash = NSMenuItem(
                title: L10n.tr("action.move_to_trash"),
                action: #selector(MenuActionProxy.invoke(_:)),
                keyEquivalent: ""
            )
            let proxy = MenuActionProxy(onTrash)
            trash.target = proxy
            objc_setAssociatedObject(trash, &menuActionProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            menu.addItem(trash)
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
