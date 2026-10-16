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

    /// Broader search under the user home (capped) for “Search this Mac”.
    func searchThisMac(query: String, limit: Int = 200) throws -> [FileItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            home,
            URL(fileURLWithPath: "/Applications", isDirectory: true)
        ]
        var results: [FileItem] = []
        var seen = Set<URL>()

        for root in roots {
            guard results.count < limit else { break }
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [
                    .isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey,
                    .fileSizeKey, .contentModificationDateKey, .creationDateKey, .contentTypeKey, .nameKey
                ],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            while let next = enumerator?.nextObject() as? URL {
                let name = next.lastPathComponent
                guard name.localizedCaseInsensitiveContains(trimmed) else { continue }
                let standardized = next.standardizedFileURL
                guard !seen.contains(standardized) else { continue }
                seen.insert(standardized)
                if let item = try? listing.makeItem(from: standardized) {
                    results.append(item)
                }
                if results.count >= limit { break }
            }
        }
        return results.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
