import AppKit
import Foundation

/// Lightweight helpers for detecting Full Disk Access / install path.
enum FullDiskAccess {
    static let didPromptDefaultsKey = "privacy.didPromptFullDiskAccess"
    static let didWarnDerivedDataKey = "privacy.didWarnDerivedDataPath"

    static var isRunningFromDerivedData: Bool {
        Bundle.main.bundlePath.contains("/DerivedData/")
    }

    static var currentAppPath: String {
        Bundle.main.bundlePath
    }

    static var applicationsCopyURL: URL {
        URL(fileURLWithPath: "/Applications/Mac Explorer.app", isDirectory: true)
    }

    static var applicationsCopyExists: Bool {
        FileManager.default.fileExists(atPath: applicationsCopyURL.path)
    }

    /// User Trash directory (canonical when available).
    static var trashDirectoryURL: URL {
        if let url = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            return url.standardizedFileURL
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true)
            .standardizedFileURL
    }

    /// Heuristic: reading the system TCC database requires Full Disk Access.
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

    /// Opens System Settings → Privacy → Full Disk Access (best-effort across macOS versions).
    @MainActor
    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    /// Kept for tests / legacy defaults; the app no longer auto-prompts on launch.
    static var shouldPromptOnLaunch: Bool {
        if isGranted() { return false }
        return !UserDefaults.standard.bool(forKey: didPromptDefaultsKey)
    }

    static var shouldWarnDerivedDataMismatch: Bool {
        guard isRunningFromDerivedData else { return false }
        return !UserDefaults.standard.bool(forKey: didWarnDerivedDataKey)
    }

    static func markPrompted() {
        UserDefaults.standard.set(true, forKey: didPromptDefaultsKey)
    }

    static func markDerivedDataWarned() {
        UserDefaults.standard.set(true, forKey: didWarnDerivedDataKey)
    }
}
