import AppKit
import Foundation

/// Built-in sidebar destinations the user can show/hide in Settings.
enum SidebarDestination: String, CaseIterable, Identifiable, Hashable {
    case recents
    case favorites
    case macintoshHD
    case applications
    case desktop
    case documents
    case downloads
    case movies
    case music
    case pictures
    case home
    case trash

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .recents: return L10n.tr("sidebar.section.recents")
        case .favorites: return L10n.tr("sidebar.section.favorites")
        case .macintoshHD:
            // Prefer the live boot volume name (Finder-like), else fallback string.
            if let name = Self.bootVolumeName(), !name.isEmpty {
                return name
            }
            return L10n.tr("sidebar.macintoshHD")
        default: return L10n.tr("sidebar.\(rawValue)")
        }
    }

    var systemImage: String {
        switch self {
        case .recents: return "clock"
        case .favorites: return "star"
        case .macintoshHD: return "internaldrive"
        case .applications: return "app"
        case .desktop: return "desktopcomputer"
        case .documents: return "doc"
        case .downloads: return "arrow.down.circle"
        case .movies: return "film"
        case .music: return "music.note"
        case .pictures: return "photo"
        case .home: return "house"
        case .trash: return "trash"
        }
    }

    /// AppKit system `NSImage` name when Finder ships dedicated artwork (else `nil` → URL / SF Symbol).
    var systemNSImageName: String? {
        switch self {
        case .trash: return NSImage.trashEmptyName
        case .macintoshHD: return NSImage.computerName
        case .home: return NSImage.homeTemplateName
        default: return nil
        }
    }

    /// Grouping used in Settings → Sidebar and sidebar section headers.
    var settingsSection: SidebarSettingsSection {
        switch self {
        case .favorites: return .favorites
        case .recents: return .recents
        case .macintoshHD, .applications, .desktop, .documents, .downloads,
             .movies, .music, .pictures, .home, .trash:
            return .locations
        }
    }

    /// Destinations that appear as single navigable rows (not section headers).
    var isNavigableLocation: Bool {
        switch self {
        case .recents, .favorites: return false
        default: return true
        }
    }

    func resolveURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .recents, .favorites:
            return nil
        case .macintoshHD:
            return URL(fileURLWithPath: "/", isDirectory: true)
        case .home:
            return home
        case .desktop:
            return home.appendingPathComponent("Desktop", isDirectory: true)
        case .documents:
            return home.appendingPathComponent("Documents", isDirectory: true)
        case .downloads:
            return home.appendingPathComponent("Downloads", isDirectory: true)
        case .movies:
            return home.appendingPathComponent("Movies", isDirectory: true)
        case .music:
            return home.appendingPathComponent("Music", isDirectory: true)
        case .pictures:
            return home.appendingPathComponent("Pictures", isDirectory: true)
        case .applications:
            return URL(fileURLWithPath: "/Applications", isDirectory: true)
        case .trash:
            return FullDiskAccess.trashDirectoryURL
        }
    }

    private static func bootVolumeName() -> String? {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        return try? root.resourceValues(forKeys: [.volumeNameKey]).volumeName
    }
}

enum SidebarSettingsSection: String, CaseIterable, Identifiable {
    case favorites
    case locations
    case recents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites: return L10n.tr("sidebar.section.favorites")
        case .locations: return L10n.tr("sidebar.section.locations")
        case .recents: return L10n.tr("sidebar.section.recents")
        }
    }

    var items: [SidebarDestination] {
        SidebarDestination.allCases.filter { $0.settingsSection == self }
    }
}

/// Display blocks for the live sidebar (coalesce consecutive location rows under “Posizioni”).
enum SidebarDisplayBlock: Identifiable {
    case favorites
    case recents
    case locations([SidebarDestination])

    var id: String {
        switch self {
        case .favorites: return "favorites"
        case .recents: return "recents"
        case .locations(let items): return "locations-" + items.map(\.rawValue).joined(separator: ",")
        }
    }

    static func blocks(from ordered: [SidebarDestination]) -> [SidebarDisplayBlock] {
        var result: [SidebarDisplayBlock] = []
        var locationBuffer: [SidebarDestination] = []

        func flushLocations() {
            guard !locationBuffer.isEmpty else { return }
            result.append(.locations(locationBuffer))
            locationBuffer = []
        }

        for destination in ordered {
            switch destination {
            case .favorites:
                flushLocations()
                result.append(.favorites)
            case .recents:
                flushLocations()
                result.append(.recents)
            default:
                locationBuffer.append(destination)
            }
        }
        flushLocations()
        return result
    }
}
