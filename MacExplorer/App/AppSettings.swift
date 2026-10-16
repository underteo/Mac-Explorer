import Foundation
import Combine
import SwiftUI

/// User preferences persisted in `UserDefaults`. Shared across windows.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
        case general
        case sidebar
        case advanced
        case menu
        case plugins

        var id: String { rawValue }
    }

    /// Selected Settings window tab (also used as deep-link from the context menu).
    @Published var settingsTab: SettingsTab = .general

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
        static let sidebarOrder = "settings.sidebarOrder"
        static let showAllExtensions = "settings.showAllFilenameExtensions"
        static let warnExtension = "settings.warnBeforeChangingExtension"
        static let warniCloud = "settings.warnBeforeRemovingFromiCloud"
        static let warnEmptyTrash = "settings.warnBeforeEmptyingTrash"
        static let removeTrash30 = "settings.removeTrashAfter30Days"
        static let foldersOnTopName = "settings.keepFoldersOnTopWhenSortingByName"
        static let foldersOnTopDesktop = "settings.keepFoldersOnTopOnDesktop"
        static let searchScope = "settings.searchScope"
        static let menuPlacements = "settings.menuActionPlacements"
    }

    enum SearchScope: String, CaseIterable, Identifiable {
        case currentFolder
        case thisMac

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .currentFolder: return L10n.tr("settings.advanced.search.current_folder")
            case .thisMac: return L10n.tr("settings.advanced.search.this_mac")
            }
        }
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

    /// Default order: Favorites → locations → Recents.
    static let defaultSidebarOrder: [String] = [
        SidebarDestination.favorites.rawValue,
        SidebarDestination.applications.rawValue,
        SidebarDestination.desktop.rawValue,
        SidebarDestination.documents.rawValue,
        SidebarDestination.downloads.rawValue,
        SidebarDestination.movies.rawValue,
        SidebarDestination.music.rawValue,
        SidebarDestination.pictures.rawValue,
        SidebarDestination.home.rawValue,
        SidebarDestination.trash.rawValue,
        SidebarDestination.recents.rawValue
    ]

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

    /// Ordered sidebar destinations (favorites / locations / recents).
    @Published var sidebarOrder: [String] {
        didSet {
            defaults.set(sidebarOrder, forKey: Keys.sidebarOrder)
        }
    }

    @Published var showAllFilenameExtensions: Bool {
        didSet { defaults.set(showAllFilenameExtensions, forKey: Keys.showAllExtensions) }
    }

    @Published var warnBeforeChangingExtension: Bool {
        didSet { defaults.set(warnBeforeChangingExtension, forKey: Keys.warnExtension) }
    }

    @Published var warnBeforeRemovingFromiCloud: Bool {
        didSet { defaults.set(warnBeforeRemovingFromiCloud, forKey: Keys.warniCloud) }
    }

    @Published var warnBeforeEmptyingTrash: Bool {
        didSet { defaults.set(warnBeforeEmptyingTrash, forKey: Keys.warnEmptyTrash) }
    }

    /// Mirrors Finder’s “Remove items from the Trash after 30 days” when possible.
    @Published var removeTrashAfter30Days: Bool {
        didSet {
            defaults.set(removeTrashAfter30Days, forKey: Keys.removeTrash30)
            UserDefaults(suiteName: "com.apple.finder")?.set(removeTrashAfter30Days, forKey: "FXRemoveOldTrashItems")
        }
    }

    @Published var keepFoldersOnTopWhenSortingByName: Bool {
        didSet { defaults.set(keepFoldersOnTopWhenSortingByName, forKey: Keys.foldersOnTopName) }
    }

    @Published var keepFoldersOnTopOnDesktop: Bool {
        didSet { defaults.set(keepFoldersOnTopOnDesktop, forKey: Keys.foldersOnTopDesktop) }
    }

    @Published var searchScope: SearchScope {
        didSet { defaults.set(searchScope.rawValue, forKey: Keys.searchScope) }
    }

    /// Per-action placement: context menu / Azioni menu / hidden.
    @Published var menuActionPlacements: [String: String] {
        didSet { defaults.set(menuActionPlacements, forKey: Keys.menuPlacements) }
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

        if let savedOrder = defaults.array(forKey: Keys.sidebarOrder) as? [String], !savedOrder.isEmpty {
            self.sidebarOrder = Self.normalizedSidebarOrder(savedOrder)
        } else {
            self.sidebarOrder = Self.defaultSidebarOrder
        }

        self.showAllFilenameExtensions = defaults.object(forKey: Keys.showAllExtensions) as? Bool ?? true
        self.warnBeforeChangingExtension = defaults.object(forKey: Keys.warnExtension) as? Bool ?? true
        self.warnBeforeRemovingFromiCloud = defaults.object(forKey: Keys.warniCloud) as? Bool ?? true
        self.warnBeforeEmptyingTrash = defaults.object(forKey: Keys.warnEmptyTrash) as? Bool ?? true

        if let saved = defaults.object(forKey: Keys.removeTrash30) as? Bool {
            self.removeTrashAfter30Days = saved
        } else if let finder = UserDefaults(suiteName: "com.apple.finder")?.object(forKey: "FXRemoveOldTrashItems") as? Bool {
            self.removeTrashAfter30Days = finder
        } else {
            self.removeTrashAfter30Days = false
        }

        self.keepFoldersOnTopWhenSortingByName = defaults.object(forKey: Keys.foldersOnTopName) as? Bool ?? true
        self.keepFoldersOnTopOnDesktop = defaults.object(forKey: Keys.foldersOnTopDesktop) as? Bool ?? false

        let scopeRaw = defaults.string(forKey: Keys.searchScope) ?? SearchScope.currentFolder.rawValue
        self.searchScope = SearchScope(rawValue: scopeRaw) ?? .currentFolder

        if let saved = defaults.dictionary(forKey: Keys.menuPlacements) as? [String: String] {
            self.menuActionPlacements = saved
        } else {
            self.menuActionPlacements = [:]
        }
    }

    func placement(for action: ContextMenuActionID) -> MenuActionPlacement {
        if let raw = menuActionPlacements[action.rawValue],
           let value = MenuActionPlacement(rawValue: raw) {
            return value
        }
        return action.defaultPlacement
    }

    func setPlacement(_ placement: MenuActionPlacement, for action: ContextMenuActionID) {
        var next = menuActionPlacements
        if placement == action.defaultPlacement {
            next.removeValue(forKey: action.rawValue)
        } else {
            next[action.rawValue] = placement.rawValue
        }
        menuActionPlacements = next
    }

    func showsInContextMenu(_ action: ContextMenuActionID) -> Bool {
        placement(for: action) == .context
    }

    func showsInActionsMenu(_ action: ContextMenuActionID) -> Bool {
        placement(for: action) == .actionsMenu
    }

    func resetMenuPlacements() {
        menuActionPlacements = [:]
    }

    /// Opens the Settings window on the given tab (default: Menu visibility).
    /// Actual presentation is handled via `\.openSettings` in the app (context menus can't call it directly).
    func openSettings(tab: SettingsTab = .menu) {
        settingsTab = tab
        // Defer so NSMenu can dismiss before the Settings scene becomes key.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .explorerOpenSettings, object: nil)
        }
    }

    func keepFoldersOnTop(directory: URL, sortKey: FileSortKey) -> Bool {
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
            .standardizedFileURL
        if keepFoldersOnTopOnDesktop, directory.standardizedFileURL == desktop {
            return true
        }
        if sortKey == .name, keepFoldersOnTopWhenSortingByName {
            return true
        }
        return false
    }

    /// All destinations in user order, appending any newly added ones at the end.
    var orderedSidebarDestinations: [SidebarDestination] {
        Self.normalizedSidebarOrder(sidebarOrder).compactMap { SidebarDestination(rawValue: $0) }
    }

    /// Visible destinations in sidebar order.
    var orderedVisibleSidebarDestinations: [SidebarDestination] {
        orderedSidebarDestinations.filter { isSidebarItemVisible($0) }
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

    func moveSidebarItem(from source: IndexSet, to destination: Int) {
        var order = orderedSidebarDestinations.map(\.rawValue)
        order.move(fromOffsets: source, toOffset: destination)
        sidebarOrder = order
    }

    /// Reorder items within one settings section (e.g. Posizioni) while preserving overall section layout.
    func moveSidebarItem(in section: SidebarSettingsSection, from source: IndexSet, to destination: Int) {
        var sectionItems = orderedSidebarDestinations.filter { $0.settingsSection == section }
        sectionItems.move(fromOffsets: source, toOffset: destination)
        let sectionIDs = sectionItems.map(\.rawValue)

        var rebuilt: [String] = []
        var sectionInserted = false
        for raw in orderedSidebarDestinations.map(\.rawValue) {
            guard let dest = SidebarDestination(rawValue: raw) else { continue }
            if dest.settingsSection == section {
                if !sectionInserted {
                    rebuilt.append(contentsOf: sectionIDs)
                    sectionInserted = true
                }
            } else {
                rebuilt.append(raw)
            }
        }
        if !sectionInserted {
            rebuilt.append(contentsOf: sectionIDs)
        }
        sidebarOrder = Self.normalizedSidebarOrder(rebuilt)
    }

    func resetSidebarOrder() {
        sidebarOrder = Self.defaultSidebarOrder
    }

    static func normalizedSidebarOrder(_ order: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in order {
            guard SidebarDestination(rawValue: raw) != nil, !seen.contains(raw) else { continue }
            seen.insert(raw)
            result.append(raw)
        }
        for destination in SidebarDestination.allCases where !seen.contains(destination.rawValue) {
            result.append(destination.rawValue)
        }
        return result
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
