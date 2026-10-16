import SwiftUI
import AppKit

struct FileContextMenu: View {
    @EnvironmentObject private var app: AppModel
    let items: [FileItem]
    let directoryURL: URL
    let onRename: (FileItem) -> Void
    let onTrash: () -> Void
    let onRefresh: () -> Void
    let onCreated: (URL) -> Void
    let onPaste: () -> Void

    var body: some View {
        Group {
            if !items.isEmpty {
                Button(L10n.tr("action.open")) {
                    items.forEach { app.fileOperations.open($0.url) }
                }
                openWithSection
                Divider()
            }

            Button(L10n.tr("action.new_folder")) {
                do {
                    let url = try app.fileOperations.createFolder(named: L10n.tr("default.new_folder"), in: directoryURL)
                    onCreated(url)
                } catch {
                    app.lastErrorMessage = error.localizedDescription
                }
            }

            Menu(L10n.tr("action.new_file")) {
                ForEach(FileTemplate.allCases) { template in
                    Button(template.displayName) {
                        do {
                            let url = try app.fileOperations.createFile(template: template, in: directoryURL)
                            onCreated(url)
                        } catch {
                            app.lastErrorMessage = error.localizedDescription
                        }
                    }
                }
            }

            if items.count == 1, let item = items.first {
                Button(L10n.tr("action.rename")) {
                    onRename(item)
                }
            }

            if !items.isEmpty {
                Button(L10n.tr("action.copy")) {
                    app.copyToClipboard(items.map(\.url), cut: false)
                }
                Button(L10n.tr("action.cut")) {
                    app.copyToClipboard(items.map(\.url), cut: true)
                }
                Button(L10n.tr("action.duplicate")) {
                    do {
                        for item in items {
                            _ = try app.fileOperations.duplicate(item.url)
                        }
                        onRefresh()
                    } catch {
                        app.lastErrorMessage = error.localizedDescription
                    }
                }
                Button(L10n.tr("action.copy_path")) {
                    app.fileOperations.copyPathToPasteboard(items.map(\.url))
                }
                Button(L10n.tr("action.get_info")) {
                    if let first = items.first {
                        do {
                            app.infoSummary = try app.fileOperations.makeInfo(for: first.url)
                        } catch {
                            app.lastErrorMessage = error.localizedDescription
                        }
                    }
                }
                Button(L10n.tr("action.reveal_finder")) {
                    app.fileOperations.revealInFinder(items.map(\.url))
                }
            }

            if app.fileClipboard != nil {
                Button(L10n.tr("action.paste")) {
                    onPaste()
                }
            }

            favoritesSection

            Divider()

            pluginSection

            if !items.isEmpty {
                Button(L10n.tr("action.move_to_trash"), role: .destructive) {
                    onTrash()
                }
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
        if items.count == 1, let item = items.first, item.isDirectory {
            favoriteButtons(for: item.url)
        } else if items.isEmpty {
            // Empty background: allow favoriting the folder currently shown.
            favoriteButtons(for: directoryURL)
        }
    }

    @ViewBuilder
    private func favoriteButtons(for url: URL) -> some View {
        if app.isFavorite(url) {
            Button(L10n.tr("favorites.remove")) {
                app.removeFavorite(url: url)
            }
        } else {
            Button(L10n.tr("favorites.add")) {
                _ = app.addFavorite(url)
            }
        }
    }

    @ViewBuilder
    private var pluginSection: some View {
        // Empty background → current folder, so plugins can act on the pane directory.
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
        if !plugins.isEmpty {
            Divider()
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
