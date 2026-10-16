import XCTest
@testable import MacExplorer

final class NavigationHistoryTests: XCTestCase {
    func testHistoryBackForward() {
        let a = URL(fileURLWithPath: "/tmp/a")
        let b = URL(fileURLWithPath: "/tmp/b")
        let c = URL(fileURLWithPath: "/tmp/c")
        var history = NavigationHistory(initial: a)
        history.navigate(to: b)
        history.navigate(to: c)
        XCTAssertEqual(history.goBack(), b)
        XCTAssertEqual(history.goBack(), a)
        XCTAssertEqual(history.goForward(), b)
        XCTAssertEqual(history.goForward(), c)
    }

    func testHistoryBounds() {
        var history = NavigationHistory(initial: URL(fileURLWithPath: "/tmp"))
        XCTAssertNil(history.goBack())
        XCTAssertNil(history.goForward())
        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }
}
