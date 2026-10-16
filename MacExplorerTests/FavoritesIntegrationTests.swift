import XCTest
@testable import MacExplorer

@MainActor
final class FavoritesIntegrationTests: XCTestCase {
    func testAddFavoriteUpdatesAppModelMirror() {
        let suiteName = "MacExplorerTests.FavUI.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = FavoritesStore(defaults: defaults)
        let app = AppModel(favoritesStore: store)
        XCTAssertTrue(app.favoriteItems.isEmpty)

        let folder = URL(fileURLWithPath: "/tmp/MacExplorerFav-\(UUID().uuidString)", isDirectory: true)
        XCTAssertTrue(app.addFavorite(folder))
        XCTAssertEqual(app.favoriteItems.count, 1)
        XCTAssertTrue(app.isFavorite(folder))
        XCTAssertEqual(app.favoriteItems.first?.name, folder.lastPathComponent)
    }

    func testFavoritePathNormalizationMatchesSymlinkVariants() throws {
        let suiteName = "MacExplorerTests.FavNorm.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FavoritesStore(defaults: defaults)

        // On macOS /tmp often resolves to /private/tmp
        let viaTmp = URL(fileURLWithPath: "/tmp", isDirectory: true)
        XCTAssertTrue(store.add(viaTmp))
        let viaPrivate = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
        XCTAssertTrue(store.contains(viaPrivate))
        XCTAssertFalse(store.add(viaPrivate), "Duplicate after normalization should be ignored")
        XCTAssertEqual(store.items.count, 1)
    }

    func testRemoveFavoriteUpdatesMirror() {
        let suiteName = "MacExplorerTests.FavRem.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let app = AppModel(favoritesStore: FavoritesStore(defaults: defaults))
        let url = URL(fileURLWithPath: "/Applications", isDirectory: true)
        XCTAssertTrue(app.addFavorite(url))
        app.removeFavorite(url: url)
        XCTAssertTrue(app.favoriteItems.isEmpty)
        XCTAssertFalse(app.isFavorite(url))
    }

    func testCreateEmptyTextFileSucceeds() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreateEmpty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let ops = FileOperationsService()
        let url = try ops.createFile(template: .txt, in: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), Data())
    }

    func testCreateAllTemplatesThenList() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreateAll-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let ops = FileOperationsService()
        let listing = DirectoryListingService()
        for template in FileTemplate.allCases {
            _ = try ops.createFile(template: template, in: root)
        }
        let items = try listing.listContents(of: root)
        XCTAssertEqual(items.filter { !$0.isDirectory }.count, FileTemplate.allCases.count)
    }

    func testCreateFolderAndFavoriteIt() throws {
        let suiteName = "MacExplorerTests.FavFolder.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavFolder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let ops = FileOperationsService()
        let folder = try ops.createFolder(named: "Pinned", in: root)
        let app = AppModel(favoritesStore: FavoritesStore(defaults: defaults))
        XCTAssertTrue(app.addFavorite(folder))
        XCTAssertTrue(app.isFavorite(folder))
        XCTAssertEqual(app.favoriteItems.map(\.name), ["Pinned"])
    }

    func testNavigationHistoryWithFavoriteJump() {
        var history = NavigationHistory(initial: URL(fileURLWithPath: "/Users"))
        history.navigate(to: URL(fileURLWithPath: "/Applications"))
        history.navigate(to: URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(history.goBack()?.path, "/Applications")
        history.navigate(to: URL(fileURLWithPath: "/Library"))
        XCTAssertFalse(history.canGoForward)
        XCTAssertTrue(history.canGoBack)
    }

    func testJSONTemplateIsValidJSON() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("JSONTpl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try FileOperationsService().createFile(template: .json, in: root)
        let data = try Data(contentsOf: url)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }
}
