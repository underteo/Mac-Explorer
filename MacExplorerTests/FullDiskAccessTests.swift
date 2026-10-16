import XCTest
@testable import MacExplorer

final class FullDiskAccessTests: XCTestCase {
    func testPromptFlagRoundTrip() {
        let key = FullDiskAccess.didPromptDefaultsKey
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        // Without FDA we would prompt; with FDA we would not — either way markPrompted stops future prompts.
        FullDiskAccess.markPrompted()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
        XCTAssertFalse(FullDiskAccess.shouldPromptOnLaunch)
    }

    func testIsGrantedIsDeterministic() {
        let a = FullDiskAccess.isGranted()
        let b = FullDiskAccess.isGranted()
        XCTAssertEqual(a, b)
    }

    func testDerivedDataPathDetection() {
        // Test host may or may not run from DerivedData; just ensure the API is stable.
        _ = FullDiskAccess.isRunningFromDerivedData
        XCTAssertFalse(FullDiskAccess.currentAppPath.isEmpty)
    }
}
