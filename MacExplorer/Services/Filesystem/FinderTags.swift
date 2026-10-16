import AppKit
import Foundation
import SwiftUI

/// Finder’s seven color tags — stored via `URLResourceValues.tagNames` (same as Finder).
enum FinderColorTag: String, CaseIterable, Identifiable, Sendable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case gray = "Gray"

    var id: String { rawValue }

    /// Localized names Finder may persist on non-English systems.
    var aliases: [String] {
        switch self {
        case .red: return ["Red", "Rosso", "Rouge", "Rot"]
        case .orange: return ["Orange", "Arancione", "Orange", "Orange"]
        case .yellow: return ["Yellow", "Giallo", "Jaune", "Gelb"]
        case .green: return ["Green", "Verde", "Vert", "Grün"]
        case .blue: return ["Blue", "Blu", "Bleu", "Blau"]
        case .purple: return ["Purple", "Viola", "Violet", "Lila", "Purple"]
        case .gray: return ["Gray", "Grey", "Grigio", "Gris", "Grau"]
        }
    }

    var displayName: String {
        switch self {
        case .red: return L10n.tr("tag.red")
        case .orange: return L10n.tr("tag.orange")
        case .yellow: return L10n.tr("tag.yellow")
        case .green: return L10n.tr("tag.green")
        case .blue: return L10n.tr("tag.blue")
        case .purple: return L10n.tr("tag.purple")
        case .gray: return L10n.tr("tag.gray")
        }
    }

    /// Finder tag swatches use the semantic system colors (same family as Finder’s
    /// colored folders / dots). `NSWorkspace.fileLabelColors` is the older pastel
    /// label palette and does not match modern Finder tag chrome.
    var nsColor: NSColor {
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .gray: return .systemGray
        }
    }

    var color: Color { Color(nsColor: nsColor) }

    static func matching(_ name: String) -> FinderColorTag? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return allCases.first { tag in
            tag.aliases.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
    }

}

enum FinderTags {
    static func read(from url: URL) -> [String] {
        (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
    }

    static func write(_ tags: [String], to url: URL) throws {
        var mutable = url
        var values = URLResourceValues()
        values.tagNames = tags
        try mutable.setResourceValues(values)
    }

    /// Toggle a Finder color tag on all URLs (shared system tags with Finder).
    static func toggle(_ color: FinderColorTag, on urls: [URL]) throws {
        try toggle(named: color.rawValue, on: urls)
    }

    /// Toggle a tag by name (color or custom). Shared with Finder via `tagNames`.
    static func toggle(named name: String, on urls: [URL]) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let canonical = FinderColorTag.matching(trimmed)?.rawValue ?? trimmed
        for url in urls {
            var tags = read(from: url)
            if let existing = tags.first(where: { $0.caseInsensitiveCompare(canonical) == .orderedSame
                || (FinderColorTag.matching($0) != nil && FinderColorTag.matching($0) == FinderColorTag.matching(canonical)) }) {
                tags.removeAll { $0.caseInsensitiveCompare(existing) == .orderedSame }
            } else {
                tags.append(canonical)
            }
            try write(tags, to: url)
        }
    }

    static func add(named name: String, to urls: [URL]) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let canonical = FinderColorTag.matching(trimmed)?.rawValue ?? trimmed
        for url in urls {
            var tags = read(from: url)
            if tags.contains(where: { $0.caseInsensitiveCompare(canonical) == .orderedSame }) { continue }
            tags.append(canonical)
            try write(tags, to: url)
        }
    }

    static func isOn(_ color: FinderColorTag, for url: URL) -> Bool {
        read(from: url).contains { FinderColorTag.matching($0) == color }
    }

    /// Finder’s favorite / sidebar tags when available (same list “Show All” expands).
    static func favoriteTagNames() -> [String] {
        let defaults = UserDefaults(suiteName: "com.apple.finder") ?? .standard
        if let names = defaults.array(forKey: "FavoriteTagNames") as? [String] {
            return names.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        // Older / alternate key used on some macOS builds.
        if let names = defaults.array(forKey: "FavoriteTags") as? [String] {
            return names.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return []
    }

    static func colors(in tagNames: [String]) -> [FinderColorTag] {
        var seen = Set<FinderColorTag>()
        var result: [FinderColorTag] = []
        for name in tagNames {
            if let color = FinderColorTag.matching(name), !seen.contains(color) {
                seen.insert(color)
                result.append(color)
            }
        }
        return result
    }

    /// Opens Finder’s Get Info so the user can edit custom tags / folder look.
    static func revealFinderInfo(for url: URL) {
        let script = """
        tell application "Finder"
          activate
          open information window of (POSIX file "\(url.path.replacingOccurrences(of: "\"", with: "\\\""))" as alias)
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
