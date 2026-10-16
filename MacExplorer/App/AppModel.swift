import Foundation
import SwiftUI
import Combine

struct FileClipboard: Equatable {
    var urls: [URL]
    var isCut: Bool
}

enum ExplorerPaneID: String, Hashable, Sendable {
    case primary
    case secondary
}

@MainActor
final class AppModel: ObservableObject {
    var filesystem: DirectoryListingService
    let fileOperations: FileOperationsService
    let openWith: OpenWithService
    let favoritesStore: FavoritesStore
    let recentsStore: RecentsStore
    let pluginManager: PluginManager
    let searchService: DirectorySearchService

    @Published var tabs: [ExplorerTab]
    @Published var selectedTabID: UUID
    @Published var dualPaneEnabled: Bool = false
    @Published var activePaneID: ExplorerPaneID = .primary
    @Published var secondaryPane: PaneState
    @Published var isEditingText: Bool = false
    @Published var transferProgress: TransferProgress?
    @Published var lastErrorMessage: String?
    @Published private(set) var favoriteItems: [FavoriteItem] = []
    @Published var recentItems: [FavoriteItem] = []
    @Published var showHiddenFiles: Bool = false {
        didSet {
            filesystem.includeHiddenFiles = showHiddenFiles
        }
    }
    @Published var fileClipboard: FileClipboard?
    @Published var infoSummary: FileInfoSummary?

    private var cancellables = Set<AnyCancellable>()

    init(
        rootURL: URL? = nil,
        filesystem: DirectoryListingService = DirectoryListingService(),
        fileOperations: FileOperationsService = FileOperationsService(),
        openWith: OpenWithService = OpenWithService(),
        favoritesStore: FavoritesStore = FavoritesStore(),
        recentsStore: RecentsStore = RecentsStore(),
        pluginManager: PluginManager = PluginManager(),
        searchService: DirectorySearchService = DirectorySearchService()
    ) {
        self.filesystem = filesystem
        self.fileOperations = fileOperations
        self.openWith = openWith
        self.favoritesStore = favoritesStore
        self.recentsStore = recentsStore
        self.pluginManager = pluginManager
        self.searchService = searchService

        let start = rootURL ?? FileManager.default.homeDirectoryForCurrentUser
        let first = ExplorerTab(rootURL: start)
        self.tabs = [first]
        self.selectedTabID = first.id
        self.secondaryPane = PaneState(currentURL: start)
        self.favoriteItems = favoritesStore.items
        self.recentItems = recentsStore.items
        self.pluginManager.reload()

        favoritesStore.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.favoriteItems = items
            }
            .store(in: &cancellables)

        recentsStore.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.recentItems = items
            }
            .store(in: &cancellables)

        pluginManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var selectedTab: ExplorerTab {
        get {
            tabs.first(where: { $0.id == selectedTabID }) ?? tabs[0]
        }
        set {
            if let index = tabs.firstIndex(where: { $0.id == newValue.id }) {
                tabs[index] = newValue
            }
        }
    }

    var primaryPane: PaneState {
        get { selectedTab.pane }
        set {
            guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
            guard tabs[index].pane != newValue else { return }
            tabs[index].pane = newValue
        }
    }

    /// Pane that receives copy/cut/paste and other selection commands.
    var activePane: PaneState {
        get {
            if dualPaneEnabled, activePaneID == .secondary {
                return secondaryPane
            }
            return primaryPane
        }
        set {
            if dualPaneEnabled, activePaneID == .secondary {
                secondaryPane = newValue
            } else {
                primaryPane = newValue
            }
        }
    }

    /// Opposite pane — destination for copy/move between panes.
    var inactivePane: PaneState {
        if dualPaneEnabled, activePaneID == .secondary {
            return primaryPane
        }
        return secondaryPane
    }

    func activatePane(_ id: ExplorerPaneID) {
        let resolved = dualPaneEnabled ? id : .primary
        // Avoid publishing when unchanged — selection highlight must stay snappy.
        guard activePaneID != resolved else { return }
        activePaneID = resolved
    }

    func newTab(url: URL? = nil) {
        let tab = ExplorerTab(rootURL: url ?? FileManager.default.homeDirectoryForCurrentUser)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if selectedTabID == id {
            selectedTabID = tabs[min(index, tabs.count - 1)].id
        }
    }

    func recordRecent(_ url: URL) {
        recentsStore.record(url)
        recentItems = recentsStore.items
    }

    @discardableResult
    func addFavorite(_ url: URL) -> Bool {
        let added = favoritesStore.add(url)
        favoriteItems = favoritesStore.items
        return added
    }

    func removeFavorite(url: URL) {
        favoritesStore.remove(url: url)
        favoriteItems = favoritesStore.items
    }

    func removeFavorite(id: UUID) {
        favoritesStore.remove(id)
        favoriteItems = favoritesStore.items
    }

    func isFavorite(_ url: URL) -> Bool {
        favoritesStore.contains(url)
    }

    func copyToClipboard(_ urls: [URL], cut: Bool) {
        guard !urls.isEmpty else { return }
        fileClipboard = FileClipboard(urls: urls, isCut: cut)
        fileOperations.copyPathToPasteboard(urls)
    }

    func clearClipboard() {
        fileClipboard = nil
    }
}

struct TransferProgress: Equatable {
    var completed: Int
    var total: Int
    var isCancelled: Bool = false

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}
