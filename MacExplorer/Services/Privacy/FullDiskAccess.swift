import AppKit
import Foundation

/// Full Disk Access cannot be granted by the app — only detected and routed to System Settings.
enum FullDiskAccess {
    static let didPromptDefaultsKey = "privacy.didPromptFullDiskAccess"
    static let didWarnDerivedDataKey = "privacy.didWarnDerivedDataPath"

    /// True when this process looks like an Xcode DerivedData build (TCC grants often stick to another copy).
    static var isRunningFromDerivedData: Bool {
        Bundle.main.bundlePath.contains("/DerivedData/")
    }

    static var currentAppPath: String {
        Bundle.main.bundlePath
    }

    /// Prefer the stable /Applications copy when present.
    static var applicationsCopyURL: URL {
        URL(fileURLWithPath: "/Applications/Mac Explorer.app", isDirectory: true)
    }

    static var applicationsCopyExists: Bool {
        FileManager.default.fileExists(atPath: applicationsCopyURL.path)
    }

    /// Heuristic: actually reading the system TCC database requires Full Disk Access.
    /// (`isReadableFile` alone is unreliable — the file can appear mode 644 without FDA.)
    static func isGranted() -> Bool {
        let tcc = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")
        do {
            let handle = try FileHandle(forReadingFrom: tcc)
            defer { try? handle.close() }
            let chunk = try handle.read(upToCount: 64) ?? Data()
            return !chunk.isEmpty
        } catch {
            return false
        }
    }

    static var shouldPromptOnLaunch: Bool {
        if isGranted() { return false }
        return !UserDefaults.standard.bool(forKey: didPromptDefaultsKey)
    }

    /// Warn once when FDA may be granted to /Applications but we're still running DerivedData.
    static var shouldWarnDerivedDataMismatch: Bool {
        guard isRunningFromDerivedData else { return false }
        guard !UserDefaults.standard.bool(forKey: didWarnDerivedDataKey) else { return false }
        // Always warn once for DerivedData — Desktop TCC is path-sensitive with ad-hoc builds.
        return true
    }

    static func markPrompted() {
        UserDefaults.standard.set(true, forKey: didPromptDefaultsKey)
    }

    static func markDerivedDataWarned() {
        UserDefaults.standard.set(true, forKey: didWarnDerivedDataKey)
    }

    static func openSystemSettings() {
        PrivacySettingsOpener.openFullDiskAccess()
    }

    static func openApplicationsCopy() {
        if applicationsCopyExists {
            NSWorkspace.shared.open(applicationsCopyURL)
        } else {
            openSystemSettings()
        }
    }
}
