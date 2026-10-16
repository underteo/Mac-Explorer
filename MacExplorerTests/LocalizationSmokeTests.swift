import XCTest
@testable import MacExplorer

final class LocalizationSmokeTests: XCTestCase {
    func testEssentialKeysResolveFromStringsTables() throws {
        let bundle = try XCTUnwrap(Bundle(identifier: "com.thehordeforge.MacExplorer"))
        let keys = [
            "sidebar.home",
            "sidebar.desktop",
            "toolbar.open_folder",
            "toolbar.refresh",
            "state.empty.title",
            "settings.plugins",
            "path.edit",
            "command.new_window",
            "command.new_tab"
        ]
        for key in keys {
            let value = NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: "", comment: "")
            XCTAssertFalse(value.isEmpty, "Missing translation for \(key)")
            XCTAssertNotEqual(value, key, "Key \(key) should resolve to a human string")
        }
    }

    func testItalianTablePresent() throws {
        let bundle = try XCTUnwrap(Bundle(identifier: "com.thehordeforge.MacExplorer"))
        let itPath = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "it")
            ?? bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: "it.lproj")
        XCTAssertNotNil(itPath, "Italian Localizable.strings should be in the app bundle")
    }
}
