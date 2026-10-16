import XCTest
@testable import MacExplorer

@MainActor
final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "MacExplorerTests.Settings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaults() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.language, .system)
        XCTAssertEqual(settings.interfaceZoom, 1.0)
        XCTAssertEqual(settings.newWindowLocation, .recents)
        XCTAssertTrue(settings.openFoldersInTabs)
    }

    func testZoomClampedAndPersisted() {
        let settings = AppSettings(defaults: defaults)
        settings.interfaceZoom = 0.4
        XCTAssertEqual(settings.interfaceZoom, 0.5)
        settings.interfaceZoom = 1.66
        XCTAssertEqual(settings.interfaceZoom, 1.5)
        settings.interfaceZoom = 1.2

        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.interfaceZoom, 1.2, accuracy: 0.001)
    }

    func testLanguageAndNewWindowPersist() {
        let settings = AppSettings(defaults: defaults)
        settings.language = .italian
        settings.newWindowLocation = .downloads
        settings.openFoldersInTabs = false

        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.language, .italian)
        XCTAssertEqual(restored.newWindowLocation, .downloads)
        XCTAssertFalse(restored.openFoldersInTabs)
    }

    func testResolveNewWindowHome() {
        let settings = AppSettings(defaults: defaults)
        settings.newWindowLocation = .home
        XCTAssertEqual(
            settings.resolveNewWindowURL().path,
            FileManager.default.homeDirectoryForCurrentUser.path
        )
    }

    func testSidebarVisibilityDefaultsAndToggle() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.isSidebarItemVisible(.recents))
        XCTAssertTrue(settings.isSidebarItemVisible(.trash))
        XCTAssertFalse(settings.isSidebarItemVisible(.movies))

        settings.setSidebarItem(.movies, visible: true)
        let restored = AppSettings(defaults: defaults)
        XCTAssertTrue(restored.isSidebarItemVisible(.movies))
    }
}
