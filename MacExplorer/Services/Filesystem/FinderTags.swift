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

    var color: Color {
        switch self {
        case .red: return Color(red: 0.92, green: 0.30, blue: 0.28)
        case .orange: return Color(red: 0.96, green: 0.58, blue: 0.20)
        case .yellow: return Color(red: 0.97, green: 0.80, blue: 0.20)
        case .green: return Color(red: 0.40, green: 0.78, blue: 0.35)
        case .blue: return Color(red: 0.30, green: 0.55, blue: 0.95)
        case .purple: return Color(red: 0.68, green: 0.40, blue: 0.90)
        case .gray: return Color(red: 0.65, green: 0.65, blue: 0.68)
        }
    }

    var nsColor: NSColor {
        switch self {
        case .red: return NSColor(calibratedRed: 0.92, green: 0.30, blue: 0.28, alpha: 1)
        case .orange: return NSColor(calibratedRed: 0.96, green: 0.58, blue: 0.20, alpha: 1)
        case .yellow: return NSColor(calibratedRed: 0.97, green: 0.80, blue: 0.20, alpha: 1)
        case .green: return NSColor(calibratedRed: 0.40, green: 0.78, blue: 0.35, alpha: 1)
        case .blue: return NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.95, alpha: 1)
        case .purple: return NSColor(calibratedRed: 0.68, green: 0.40, blue: 0.90, alpha: 1)
        case .gray: return NSColor(calibratedRed: 0.65, green: 0.65, blue: 0.68, alpha: 1)
        }
    }

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
        for url in urls {
            var tags = read(from: url)
            if let existing = tags.first(where: { FinderColorTag.matching($0) == color }) {
                tags.removeAll { $0.caseInsensitiveCompare(existing) == .orderedSame }
            } else {
                // Prefer English raw value — Finder accepts it and syncs across locales.
                tags.append(color.rawValue)
            }
            try write(tags, to: url)
        }
    }

    static func isOn(_ color: FinderColorTag, for url: URL) -> Bool {
        read(from: url).contains { FinderColorTag.matching($0) == color }
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
