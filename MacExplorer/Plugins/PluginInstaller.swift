import AppKit
import Foundation

enum PluginInstallError: Error, LocalizedError, Equatable {
    case missingManifest
    case invalidManifest(String)
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingManifest:
            return L10n.tr("error.plugin_missing_manifest")
        case .invalidManifest(let message):
            return message
        case .copyFailed(let message):
            return message
        }
    }
}

extension PluginManager {
    /// Copies a plugin folder (must contain `manifest.json`) into the live Plugins directory and reloads.
    @discardableResult
    func install(from sourceDirectory: URL) throws -> LoadedPlugin {
        let source = sourceDirectory.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDir), isDir.boolValue else {
            throw PluginInstallError.missingManifest
        }
        let manifestURL = source.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PluginInstallError.missingManifest
        }

        let data: Data
        let manifest: PluginManifest
        do {
            data = try Data(contentsOf: manifestURL)
            manifest = try Self.parseManifest(data: data)
        } catch {
            throw PluginInstallError.invalidManifest(error.localizedDescription)
        }

        try? FileManager.default.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)

        // Prefer stable folder name from id last component; fall back to source folder name.
        let folderName = sanitizedFolderName(for: manifest.id, fallback: source.lastPathComponent)
        let destination = pluginsDirectory.appendingPathComponent(folderName, isDirectory: true)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            throw PluginInstallError.copyFailed(error.localizedDescription)
        }

        if let executable = manifest.executable {
            do {
                let exeURL = try Self.resolvedExecutableURL(executable: executable, pluginRoot: destination)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: exeURL.path
                )
            } catch {
                // Non-fatal: menu still loads; run may fail until user chmod +x.
            }
        }

        reload()
        guard let installed = plugins.first(where: { $0.manifest.id == manifest.id && $0.loadError == nil }) else {
            throw PluginInstallError.copyFailed(L10n.tr("error.plugin_install_reload"))
        }
        return installed
    }

    /// NSOpenPanel → install selected plugin folder.
    func presentInstallPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L10n.tr("plugins.install.panel_message")
        panel.prompt = L10n.tr("plugins.install.panel_prompt")
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do {
                    _ = try self?.install(from: url)
                } catch {
                    // Surface via Notification so any open explorer window can show it.
                    NotificationCenter.default.post(
                        name: .explorerPluginInstallFailed,
                        object: error.localizedDescription
                    )
                }
            }
        }
    }

    private func sanitizedFolderName(for pluginID: String, fallback: String) -> String {
        let last = pluginID.split(separator: ".").last.map(String.init) ?? pluginID
        let cleaned = last.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return fallback }
        return cleaned
    }
}
