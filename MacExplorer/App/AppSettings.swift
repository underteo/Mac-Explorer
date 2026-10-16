import Foundation
import Combine
import SwiftUI

/// User preferences persisted in `UserDefaults`. Shared across windows.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum LanguagePreference: String, CaseIterable, Identifiable {
        case system
        case english
        case italian

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return L10n.tr("settings.language.system")
            case .english: return "English"
            case .italian: return "Italiano"
            }
        }

        /// BCP-47 code used to load `.lproj`, or `nil` for system.
        var languageCode: String? {
            switch self {
            case .system: return nil
            case .english: return "en"
            case .italian: return "it"
            }
        }
    }

    enum NewWindowLocation: String, CaseIterable, Identifiable {
        case recents
        case home
        case desktop
        case documents
        case downloads
        case applications

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .recents: return L10n.tr("sidebar.section.recents")
            case .home: return L10n.tr("sidebar.home")
            case .desktop: return L10n.tr("sidebar.desktop")
            case .documents: return L10n.tr("sidebar.documents")
            case .downloads: return L10n.tr("sidebar.downloads")
            case .applications: return L10n.tr("sidebar.applications")
            }
        }

        var systemImage: String {
            switch self {
            case .recents: return "clock"
            case .home: return "house"
            case .desktop: return "desktopcomputer"
            case .documents: return "doc"
            case .downloads: return "arrow.down.circle"
            case .applications: return "app"
            }
        }
    }

    private enum Keys {
        static let language = "settings.language"
        static let zoom = "settings.interfaceZoom"
        static let newWindow = "settings.newWindowLocation"
        static let openInTabs = "settings.openFoldersInTabs"
        static let sidebarVisible = "settings.sidebarVisibleItems"
    }

    /// Default sidebar visibility (Finder-like: media folders off, core locations on).
    static let defaultSidebarVisible: Set<String> = Set([
        SidebarDestination.recents.rawValue,
        SidebarDestination.favorites.rawValue,
        SidebarDestination.applications.rawValue,
        SidebarDestination.desktop.rawValue,
        SidebarDestination.documents.rawValue,
        SidebarDestination.downloads.rawValue,
        SidebarDestination.home.rawValue,
        SidebarDestination.trash.rawValue
    ])

    private let defaults: UserDefaults

    @Published var language: LanguagePreference {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    /// 0.5 ... 1.5, default 1.0 (100%).
    @Published var interfaceZoom: Double {
        didSet {
            let clamped = Self.clampZoom(interfaceZoom)
            if clamped != interfaceZoom {
                interfaceZoom = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.zoom)
        }
    }

    @Published var newWindowLocation: NewWindowLocation {
        didSet { defaults.set(newWindowLocation.rawValue, forKey: Keys.newWindow) }
    }

    @Published var openFoldersInTabs: Bool {
        didSet { defaults.set(openFoldersInTabs, forKey: Keys.openInTabs) }
    }

    @Published var sidebarVisibleItems: Set<String> {
        didSet {
            defaults.set(Array(sidebarVisibleItems), forKey: Keys.sidebarVisible)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let langRaw = defaults.string(forKey: Keys.language) ?? LanguagePreference.system.rawValue
        self.language = LanguagePreference(rawValue: langRaw) ?? .system

        let storedZoom = defaults.object(forKey: Keys.zoom) as? Double
        self.interfaceZoom = Self.clampZoom(storedZoom ?? 1.0)

        let locRaw = defaults.string(forKey: Keys.newWindow) ?? NewWindowLocation.recents.rawValue
        self.newWindowLocation = NewWindowLocation(rawValue: locRaw) ?? .recents

        if defaults.object(forKey: Keys.openInTabs) == nil {
            self.openFoldersInTabs = true
        } else {
            self.openFoldersInTabs = defaults.bool(forKey: Keys.openInTabs)
        }

        if let saved = defaults.array(forKey: Keys.sidebarVisible) as? [String] {
            self.sidebarVisibleItems = Set(saved)
        } else {
            self.sidebarVisibleItems = Self.defaultSidebarVisible
        }
    }

    func isSidebarItemVisible(_ item: SidebarDestination) -> Bool {
        sidebarVisibleItems.contains(item.rawValue)
    }

    func setSidebarItem(_ item: SidebarDestination, visible: Bool) {
        if visible {
            sidebarVisibleItems.insert(item.rawValue)
        } else {
            sidebarVisibleItems.remove(item.rawValue)
        }
    }

    func bindingSidebarItem(_ item: SidebarDestination) -> Binding<Bool> {
        Binding(
            get: { self.isSidebarItemVisible(item) },
            set: { self.setSidebarItem(item, visible: $0) }
        )
    }

    static func clampZoom(_ value: Double) -> Double {
        let stepped = (value * 10).rounded() / 10
        return min(1.5, max(0.5, stepped))
    }

    var zoomPercentLabel: String {
        "\(Int((interfaceZoom * 100).rounded()))%"
    }

    /// Bundle used by `L10n` for the current language preference.
    nonisolated static func localizationBundle(defaults: UserDefaults = .standard) -> Bundle {
        let raw = defaults.string(forKey: Keys.language) ?? LanguagePreference.system.rawValue
        guard let pref = LanguagePreference(rawValue: raw), let code = pref.languageCode else {
            return .main
        }
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    func resolveNewWindowURL(recents: RecentsStore = RecentsStore()) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch newWindowLocation {
        case .recents:
            return recents.items.first?.url ?? home
        case .home:
            return home
        case .desktop:
            return home.appendingPathComponent("Desktop", isDirectory: true)
        case .documents:
            return home.appendingPathComponent("Documents", isDirectory: true)
        case .downloads:
            return home.appendingPathComponent("Downloads", isDirectory: true)
        case .applications:
            return URL(fileURLWithPath: "/Applications", isDirectory: true)
        }
    }
}
