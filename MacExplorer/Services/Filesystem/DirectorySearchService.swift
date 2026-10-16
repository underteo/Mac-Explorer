import Foundation

struct DirectorySearchService: Sendable {
    private let listing: DirectoryListingService

    init(listing: DirectoryListingService = DirectoryListingService()) {
        self.listing = listing
    }

    /// Shallow search in the selected directory only (current scope).
    func search(query: String, in directory: URL) throws -> [FileItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let items = try listing.listContents(of: directory, sortKey: .name, ascending: true)
        return items.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
