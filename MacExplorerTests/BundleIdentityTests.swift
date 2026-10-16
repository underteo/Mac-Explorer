import XCTest
@testable import MacExplorer

final class BundleIdentityTests: XCTestCase {
    private var appBundle: Bundle {
        Bundle(identifier: "com.thehordeforge.MacExplorer") ?? Bundle.main
    }

    func testBundleIdentifier() {
        XCTAssertEqual(appBundle.bundleIdentifier, "com.thehordeforge.MacExplorer")
    }

    func testVersionReadable() {
        let version = appBundle.infoDictionary?["CFBundleShortVersionString"] as? String
        XCTAssertEqual(version, "1.0.0")
        let build = appBundle.infoDictionary?["CFBundleVersion"] as? String
        XCTAssertEqual(build, "1")
    }
}
