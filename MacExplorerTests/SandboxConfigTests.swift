import XCTest

final class SandboxConfigTests: XCTestCase {
    func testSandboxEntitlementAbsentOrFalse() throws {
        let entitlementsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MacExplorer/MacExplorer.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let text = String(decoding: data, as: UTF8.self)
        if text.contains("com.apple.security.app-sandbox") {
            XCTAssertTrue(
                text.contains("<false/>") || text.contains("<false />"),
                "Sandbox must be off when the key is present"
            )
        }
    }
}
