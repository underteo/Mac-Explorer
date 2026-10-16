import XCTest
@testable import MacExplorer

final class RenameSelectionTests: XCTestCase {
    func testFileSelectsBasenameBeforeExtension() {
        let range = RenameSelection.selectedRange(for: "Untitled.txt", isDirectory: false)
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, "Untitled".count)
    }

    func testDoubleExtensionKeepsLastExtension() {
        let range = RenameSelection.selectedRange(for: "archive.tar.gz", isDirectory: false)
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, "archive.tar".count)
    }

    func testExtensionlessFileSelectsAll() {
        let range = RenameSelection.selectedRange(for: "Untitled", isDirectory: false)
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, "Untitled".count)
    }

    func testDirectorySelectsAll() {
        let range = RenameSelection.selectedRange(for: "My.Folder", isDirectory: true)
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, "My.Folder".count)
    }
}
