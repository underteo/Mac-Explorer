import Foundation
import AppKit

struct LoadedPlugin: Identifiable, Equatable {
    var id: String { manifest.id }
    var manifest: PluginManifest
    var directoryURL: URL
    var isEnabled: Bool
    var loadError: String?
}

enum PluginError: Error, LocalizedError, Equatable {
    case invalidManifest(String)
    case pathTraversalRejected
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidManifest(let message): return message
        case .pathTraversalRejected: return L10n.tr("error.plugin_path_traversal")
        case .executionFailed(let message): return message
        }
    }
}

protocol PluginEnableStore: AnyObject {
    func isEnabled(pluginID: String) -> Bool
    func setEnabled(_ enabled: Bool, pluginID: String)
}

final class UserDefaultsPluginEnableStore: PluginEnableStore {
    private let defaults: UserDefaults
    private let prefix = "plugin.enabled."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(pluginID: String) -> Bool {
        if defaults.object(forKey: prefix + pluginID) == nil {
            return true
        }
        return defaults.bool(forKey: prefix + pluginID)
    }

    func setEnabled(_ enabled: Bool, pluginID: String) {
        defaults.set(enabled, forKey: prefix + pluginID)
    }
}

@MainActor
final class PluginManager: ObservableObject {
    @Published private(set) var plugins: [LoadedPlugin] = []

    let pluginsDirectory: URL
    private let enableStore: PluginEnableStore
    private var directoryWatcher: PluginDirectoryWatcher?
    private var becomeActiveObserver: NSObjectProtocol?
    /// When false, skip folder watch (unit tests).
    private let watchesDirectory: Bool

    init(
        pluginsDirectory: URL? = nil,
        enableStore: PluginEnableStore? = nil,
        watchDirectory: Bool = true
    ) {
        let defaultDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Mac Explorer/Plugins", isDirectory: true)
        self.pluginsDirectory = pluginsDirectory ?? defaultDir
        self.enableStore = enableStore ?? UserDefaultsPluginEnableStore()
        self.watchesDirectory = watchDirectory
        if watchDirectory {
            startHotReloadWatch()
        }
    }

    /// Rescan `pluginsDirectory`. Safe to call often; also triggered automatically on folder changes.
    func reload() {
        try? FileManager.default.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            plugins = []
            return
        }

        var loaded: [LoadedPlugin] = []
        for dir in contents {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let manifestURL = dir.appendingPathComponent("manifest.json")
            do {
                let data = try Data(contentsOf: manifestURL)
                let manifest = try Self.parseManifest(data: data)
                if let executable = manifest.executable {
                    _ = try Self.resolvedExecutableURL(executable: executable, pluginRoot: dir)
                }
                loaded.append(
                    LoadedPlugin(
                        manifest: manifest,
                        directoryURL: dir,
                        isEnabled: enableStore.isEnabled(pluginID: manifest.id),
                        loadError: nil
                    )
                )
            } catch {
                let fallbackID = dir.lastPathComponent
                loaded.append(
                    LoadedPlugin(
                        manifest: PluginManifest(
                            id: fallbackID,
                            name: fallbackID,
                            version: "0",
                            match: PluginMatchRules(),
                            menu: [],
                            executable: nil,
                            urlTemplate: nil
                        ),
                        directoryURL: dir,
                        isEnabled: false,
                        loadError: error.localizedDescription
                    )
                )
            }
        }
        plugins = loaded.sorted { $0.manifest.name.localizedStandardCompare($1.manifest.name) == .orderedAscending }
    }

    func startHotReloadWatch() {
        guard watchesDirectory else { return }
        directoryWatcher?.stop()
        let watcher = PluginDirectoryWatcher { [weak self] in
            self?.reload()
        }
        watcher.start(directoryURL: pluginsDirectory)
        directoryWatcher = watcher

        if becomeActiveObserver == nil {
            becomeActiveObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.reload()
                }
            }
        }
    }

    func setEnabled(_ enabled: Bool, pluginID: String) {
        enableStore.setEnabled(enabled, pluginID: pluginID)
        reload()
    }

    func enabledMenuProviders(for items: [FileItem]) -> [LoadedPlugin] {
        plugins.filter { plugin in
            plugin.loadError == nil && plugin.isEnabled && plugin.manifest.match.matches(items: items)
        }
    }

    func run(action: PluginMenuAction, plugin: LoadedPlugin, items: [FileItem]) -> Result<Void, PluginError> {
        do {
            if let template = plugin.manifest.urlTemplate {
                let joined = items.map(\.url.path).joined(separator: ",")
                let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
                let filled = template
                    .replacingOccurrences(of: "{path}", with: encoded)
                    .replacingOccurrences(of: "{paths}", with: encoded)
                if let url = URL(string: filled) {
                    NSWorkspace.shared.open(url)
                    return .success(())
                }
            }

            if let executable = plugin.manifest.executable {
                let exeURL = try Self.resolvedExecutableURL(executable: executable, pluginRoot: plugin.directoryURL)
                let process = Process()
                process.executableURL = exeURL
                process.arguments = [action.action ?? action.id] + items.map(\.url.path)
                process.currentDirectoryURL = plugin.directoryURL
                try process.run()
                return .success(())
            }

            return .failure(.executionFailed(L10n.tr("error.plugin_no_handler")))
        } catch let error as PluginError {
            return .failure(error)
        } catch {
            return .failure(.executionFailed(error.localizedDescription))
        }
    }

    nonisolated static func parseManifest(data: Data) throws -> PluginManifest {
        do {
            return try JSONDecoder().decode(PluginManifest.self, from: data)
        } catch {
            throw PluginError.invalidManifest(error.localizedDescription)
        }
    }

    nonisolated static func resolvedExecutableURL(executable: String, pluginRoot: URL) throws -> URL {
        let root = pluginRoot.standardizedFileURL
        let candidate: URL
        if executable.hasPrefix("/") {
            candidate = URL(fileURLWithPath: executable).standardizedFileURL
        } else {
            candidate = root.appendingPathComponent(executable).standardizedFileURL
        }
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path == root.path || candidate.path.hasPrefix(rootPath) else {
            throw PluginError.pathTraversalRejected
        }
        return candidate
    }

    func revealPluginsFolder() {
        try? FileManager.default.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(pluginsDirectory)
    }
}
