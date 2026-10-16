import Foundation

/// Lightweight helpers for detecting Full Disk Access / install path.
/// The app does not prompt to open System Settings — macOS may ask natively when needed.
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
