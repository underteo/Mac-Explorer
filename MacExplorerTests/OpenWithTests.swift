import XCTest
@testable import MacExplorer

final class OpenWithTests: XCTestCase {
    func testOpenWithCandidatesDoesNotCrash() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenWith-\(UUID().uuidString).txt")
        try Data("hello".utf8).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let apps = OpenWithService().applications(for: temp)
        XCTAssertNotNil(apps)
    }
}
