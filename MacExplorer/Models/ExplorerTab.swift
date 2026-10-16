import Foundation

struct ExplorerTab: Identifiable, Hashable {
    let id: UUID
    var title: String
    var pane: PaneState
    var searchQuery: String
    var searchResults: [FileItem]
    var isSearching: Bool
    /// Which dual-pane side the current search results belong to.
    var searchPaneID: ExplorerPaneID

    init(id: UUID = UUID(), rootURL: URL) {
        self.id = id
        self.title = rootURL.lastPathComponent
        self.pane = PaneState(currentURL: rootURL)
        self.searchQuery = ""
        self.searchResults = []
        self.isSearching = false
        self.searchPaneID = .primary
    }

    var hasActiveSearch: Bool {
        isSearching || !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct PaneState: Hashable {
    var currentURL: URL
    var items: [FileItem]
    var selectedURLs: Set<URL>
    var sortKey: FileSortKey
    var sortAscending: Bool
    var viewMode: FileViewMode
    var isLoading: Bool
    var errorMessage: String?
    var history: NavigationHistory

    init(currentURL: URL) {
        self.currentURL = currentURL
        self.items = []
        self.selectedURLs = []
        self.sortKey = .name
        self.sortAscending = true
        self.viewMode = .list
        self.isLoading = false
        self.errorMessage = nil
        self.history = NavigationHistory(initial: currentURL)
    }

    var selectedItems: [FileItem] {
        items.filter { selectedURLs.contains($0.url) }
    }
}

enum FileViewMode: String, CaseIterable, Identifiable, Sendable {
    case list
    case grid
    case columns

    var id: String { rawValue }
}
