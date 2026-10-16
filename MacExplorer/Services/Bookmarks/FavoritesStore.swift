import Foundation

struct FavoriteItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var path: String

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }

    init(id: UUID = UUID(), name: String, url: URL) {
        self.id = id
        self.name = name
        self.path = Self.normalizedPath(url)
    }

    static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [FavoriteItem]

    private let defaults: UserDefaults
    private let key = "favorites.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([FavoriteItem].self, from: data) {
            self.items = decoded
        } else {
            self.items = []
        }
    }

    @discardableResult
    func add(_ url: URL) -> Bool {
        let path = FavoriteItem.normalizedPath(url)
        guard !items.contains(where: { $0.path == path }) else { return false }
        items.append(FavoriteItem(name: url.lastPathComponent, url: url))
        persist()
        return true
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func remove(url: URL) {
        let path = FavoriteItem.normalizedPath(url)
        items.removeAll { $0.path == path }
        persist()
    }

    func contains(_ url: URL) -> Bool {
        let path = FavoriteItem.normalizedPath(url)
        return items.contains { $0.path == path }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
            defaults.synchronize()
        }
    }
}
