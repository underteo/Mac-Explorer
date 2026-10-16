import XCTest
@testable import MacExplorer

@MainActor
final class SidebarDestinationTests: XCTestCase {
    func testDestinationsNotEmptyAndStableIDs() {
        let all = SidebarDestination.allCases
        XCTAssertFalse(all.isEmpty)
        let ids = Set(all.map(\.id))
        XCTAssertEqual(ids.count, all.count)
    }

    func testNavigableLocationsResolve() {
        for destination in SidebarDestination.allCases where destination.isNavigableLocation {
            XCTAssertNotNil(destination.resolveURL(), destination.rawValue)
        }
        XCTAssertNil(SidebarDestination.recents.resolveURL())
        XCTAssertNil(SidebarDestination.favorites.resolveURL())
    }

    func testLocationsSectionContainsFolderShortcuts() {
        let locations = SidebarSettingsSection.locations.items
        XCTAssertTrue(locations.contains(.macintoshHD))
        XCTAssertEqual(SidebarDestination.macintoshHD.resolveURL()?.path, "/")
        XCTAssertTrue(locations.contains(.desktop))
        XCTAssertTrue(locations.contains(.documents))
        XCTAssertTrue(locations.contains(.home))
        XCTAssertTrue(locations.contains(.trash))
        XCTAssertFalse(locations.contains(.favorites))
        XCTAssertFalse(locations.contains(.recents))
        XCTAssertEqual(SidebarDestination.desktop.settingsSection, .locations)
    }

    func testDisplayBlocksCoalesceLocations() {
        let blocks = SidebarDisplayBlock.blocks(from: [
            .favorites, .desktop, .documents, .home, .recents
        ])
        XCTAssertEqual(blocks.count, 3)
        guard case .favorites = blocks[0] else { return XCTFail("favorites first") }
        guard case .locations(let items) = blocks[1] else { return XCTFail("locations middle") }
        XCTAssertEqual(items, [.desktop, .documents, .home])
        guard case .recents = blocks[2] else { return XCTFail("recents last") }
    }
}
