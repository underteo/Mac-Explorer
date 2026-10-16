import AppKit
import Foundation

/// Shared Finder-like context menu actions (used by SwiftUI + AppKit renderers).
@MainActor
enum FileMenuActions {
    static func open(_ items: [FileItem], app: AppModel) {
        items.forEach { app.fileOperations.open($0.url) }
    }

    static func newFolder(in directory: URL, app: AppModel, onCreated: (URL) -> Void) {
        do {
            let url = try app.fileOperations.createFolder(
                named: L10n.tr("default.new_folder"),
                in: directory
            )
            onCreated(url)
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    static func newFile(template: FileTemplate, in directory: URL, app: AppModel, onCreated: (URL) -> Void) {
        do {
            let url = try app.fileOperations.createFile(template: template, in: directory)
            onCreated(url)
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    static func paste(app: AppModel, onPaste: () -> Void) {
        guard app.fileClipboard != nil else { return }
        onPaste()
    }

    static func copy(_ items: [FileItem], app: AppModel) {
        app.copyToClipboard(items.map(\.url), cut: false)
    }

    static func cut(_ items: [FileItem], app: AppModel) {
        app.copyToClipboard(items.map(\.url), cut: true)
    }

    static func duplicate(_ items: [FileItem], app: AppModel, onRefresh: () -> Void) {
        do {
            for item in items {
                _ = try app.fileOperations.duplicate(item.url)
            }
            onRefresh()
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    static func compress(_ items: [FileItem], app: AppModel, onRefresh: () -> Void) {
        do {
            _ = try app.fileOperations.compress(items.map(\.url))
            onRefresh()
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    static func makeAlias(_ items: [FileItem], app: AppModel, onRefresh: () -> Void) {
        do {
            for item in items {
                _ = try app.fileOperations.makeAlias(of: item.url)
            }
            onRefresh()
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    static func quickLook(_ items: [FileItem]) {
        QuickLookController.shared.show(urls: items.map(\.url))
    }

    static func getInfo(_ items: [FileItem], app: AppModel) {
        guard let first = items.first else { return }
        do {
            app.infoSummary = try app.fileOperations.makeInfo(for: first.url)
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    static func copyPath(_ items: [FileItem], app: AppModel) {
        app.fileOperations.copyPathToPasteboard(items.map(\.url))
    }

    static func revealInFinder(_ items: [FileItem], app: AppModel) {
        app.fileOperations.revealInFinder(items.map(\.url))
    }

    static func toggleTag(_ color: FinderColorTag, items: [FileItem], app: AppModel, onRefresh: () -> Void) {
        do {
            try FinderTags.toggle(color, on: items.map(\.url))
            onRefresh()
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    static func customizeInFinder(_ items: [FileItem], directoryURL: URL) {
        let url = items.first?.url ?? directoryURL
        FinderTags.revealFinderInfo(for: url)
    }

    static func openInNewPane(items: [FileItem], directoryURL: URL, callbacks: FileMenuCallbacks) {
        let target: URL
        if let item = items.first {
            target = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
        } else {
            target = directoryURL
        }
        callbacks.onOpenInNewPane(target)
    }

    static func openTerminal(at directory: URL, newTab: Bool, items: [FileItem], app: AppModel) {
        let folder: URL
        if let item = items.first {
            folder = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
        } else {
            folder = directory
        }
        app.fileOperations.openInTerminal(folder, newTab: newTab)
    }

    static func compressTitle(for items: [FileItem]) -> String {
        if items.count == 1 {
            return L10n.tr("action.compress_named", items[0].name)
        }
        return L10n.tr("action.compress")
    }

    static func favoriteURL(items: [FileItem], directoryURL: URL) -> URL {
        if items.count == 1, items[0].isDirectory {
            return items[0].url
        }
        return directoryURL
    }
}
