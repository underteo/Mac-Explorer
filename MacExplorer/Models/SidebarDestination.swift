import Foundation

/// Built-in sidebar destinations the user can show/hide in Settings.
enum SidebarDestination: String, CaseIterable, Identifiable, Hashable {
    case recents
    case favorites
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
        default: return L10n.tr("sidebar.\(rawValue)")
        }
    }

    var systemImage: String {
        switch self {
        case .recents: return "clock"
        case .favorites: return "star"
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

    /// Grouping used in Settings → Sidebar (Finder-like).
    var settingsSection: SidebarSettingsSection {
        switch self {
        case .recents:
            return .top
        case .favorites, .applications, .desktop, .documents, .downloads, .movies, .music, .pictures:
            return .favorites
        case .home, .trash:
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
            return home.appendingPathComponent(".Trash", isDirectory: true)
        }
    }
}

enum SidebarSettingsSection: String, CaseIterable, Identifiable {
    case top
    case favorites
    case locations

    var id: String { rawValue }

    var title: String? {
        switch self {
        case .top: return nil
        case .favorites: return L10n.tr("sidebar.section.favorites")
        case .locations: return L10n.tr("sidebar.section.locations")
        }
    }

    var items: [SidebarDestination] {
        SidebarDestination.allCases.filter { $0.settingsSection == self }
    }
}
