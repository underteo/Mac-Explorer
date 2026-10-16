import Foundation

@MainActor
final class RecentsStore: ObservableObject {
    @Published private(set) var items: [FavoriteItem] = []

    private let defaults: UserDefaults
    private let key = "recents.v1"
    private let limit = 12

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([FavoriteItem].self, from: data) {
            items = decoded
        }
    }

    func record(_ url: URL) {
        let path = FavoriteItem.normalizedPath(url)
        items.removeAll { $0.path == path }
        items.insert(FavoriteItem(name: url.lastPathComponent, url: url), at: 0)
        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }
}
