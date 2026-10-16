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
}
