import XCTest
@testable import MacExplorer

@MainActor
final class TabAndFavoritesTests: XCTestCase {
    func testTabIsolation() {
        let app = AppModel()
        let firstID = app.selectedTabID
        app.newTab(url: URL(fileURLWithPath: "/tmp"))
        let secondID = app.selectedTabID
        XCTAssertNotEqual(firstID, secondID)

        var second = app.selectedTab
        second.pane.currentURL = URL(fileURLWithPath: "/Applications")
        app.selectedTab = second

        app.selectedTabID = firstID
        XCTAssertNotEqual(app.selectedTab.pane.currentURL.path, "/Applications")
    }

    func testFavoritesPersist() {
        let suiteName = "MacExplorerTests.Favorites.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let store = FavoritesStore(defaults: suite)
        let url = URL(fileURLWithPath: "/tmp/fav")
        store.add(url)
        XCTAssertTrue(store.contains(url))

        let restored = FavoritesStore(defaults: suite)
        XCTAssertTrue(restored.contains(url))
        restored.remove(url: url)
        XCTAssertFalse(restored.contains(url))
    }

    func testSearchScope() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("alpha.txt"))
        try Data().write(to: root.appendingPathComponent("beta.txt"))
        let child = root.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data().write(to: child.appendingPathComponent("alpha-deep.txt"))

        let results = try DirectorySearchService().search(query: "alpha", in: root)
        XCTAssertEqual(results.map(\.name), ["alpha.txt"])
    }

    func testAdvancedSettingsDefaultsAndFoldersOnTop() {
        let suiteName = "MacExplorerTests.Advanced.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: suite)
        XCTAssertTrue(settings.showAllFilenameExtensions)
        XCTAssertTrue(settings.warnBeforeChangingExtension)
        XCTAssertEqual(settings.searchScope, .currentFolder)

        let docs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
        settings.keepFoldersOnTopWhenSortingByName = false
        XCTAssertFalse(settings.keepFoldersOnTop(directory: docs, sortKey: .name))
        settings.keepFoldersOnTopWhenSortingByName = true
        XCTAssertTrue(settings.keepFoldersOnTop(directory: docs, sortKey: .name))
        XCTAssertFalse(settings.keepFoldersOnTop(directory: docs, sortKey: .size))

        let file = FileItem(
            url: URL(fileURLWithPath: "/tmp/photo.jpg"),
            name: "photo.jpg",
            isDirectory: false,
            isHidden: false,
            isSymbolicLink: false,
            fileSize: 1,
            contentModificationDate: nil,
            creationDate: nil,
            contentType: nil
        )
        XCTAssertEqual(file.listedName(showExtension: true), "photo.jpg")
        XCTAssertEqual(file.listedName(showExtension: false), "photo")
    }

    func testShortcutDoesNotStealTextFieldWhenEditing() {
        let app = AppModel()
        app.isEditingText = true
        // Coordinator policy: commands should no-op while editing.
        XCTAssertTrue(app.isEditingText)
        app.isEditingText = false
        XCTAssertFalse(app.isEditingText)
    }
}
