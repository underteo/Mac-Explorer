import XCTest
@testable import MacExplorer

@MainActor
final class DualPaneTests: XCTestCase {
    func testPaneIndependence() {
        let app = AppModel()
        app.primaryPane.currentURL = URL(fileURLWithPath: "/tmp/left")
        app.secondaryPane.currentURL = URL(fileURLWithPath: "/tmp/right")
        app.primaryPane.selectedURLs = [URL(fileURLWithPath: "/tmp/left/a")]
        app.secondaryPane.selectedURLs = [URL(fileURLWithPath: "/tmp/right/b")]
        XCTAssertNotEqual(app.primaryPane.currentURL, app.secondaryPane.currentURL)
        XCTAssertNotEqual(app.primaryPane.selectedURLs, app.secondaryPane.selectedURLs)
    }

    func testCopyLeftToRightAndMove() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dual-\(UUID().uuidString)", isDirectory: true)
        let left = root.appendingPathComponent("left", isDirectory: true)
        let right = root.appendingPathComponent("right", isDirectory: true)
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let ops = FileOperationsService()
        let file = try ops.createFile(template: .txt, in: left)

        var progressHits = 0
        try await ops.copyWithProgress(
            items: [file],
            to: right,
            overwrite: false,
            progress: { _ in progressHits += 1 },
            isCancelled: { false }
        )
        XCTAssertEqual(progressHits, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent(file.lastPathComponent).path))

        let copied = right.appendingPathComponent(file.lastPathComponent)
        try await ops.moveWithProgress(
            items: [copied],
            to: left.appendingPathComponent("nested", isDirectory: true).withDirectoryCreated(),
            overwrite: false,
            progress: { _ in },
            isCancelled: { false }
        )
    }

    func testCollisionBetweenPanesNoSilentOverwrite() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DualCol-\(UUID().uuidString)", isDirectory: true)
        let left = root.appendingPathComponent("left", isDirectory: true)
        let right = root.appendingPathComponent("right", isDirectory: true)
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let ops = FileOperationsService()
        let file = try ops.createFile(template: .txt, in: left)
        try ops.copy(items: [file], to: right)
        XCTAssertThrowsError(try ops.copy(items: [file], to: right, overwrite: false)) { error in
            guard case FilesystemError.nameCollision = error else {
                return XCTFail("Expected collision")
            }
        }
    }

    func testFailureDoesNotCorruptState() {
        let app = AppModel()
        let beforePrimary = app.primaryPane.currentURL
        let beforeSecondary = app.secondaryPane.currentURL
        app.lastErrorMessage = "boom"
        XCTAssertEqual(app.primaryPane.currentURL, beforePrimary)
        XCTAssertEqual(app.secondaryPane.currentURL, beforeSecondary)
    }

    func testActivePaneDrivesSelectionAndPasteTarget() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ActivePane-\(UUID().uuidString)", isDirectory: true)
        let left = root.appendingPathComponent("left", isDirectory: true)
        let right = root.appendingPathComponent("right", isDirectory: true)
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let ops = FileOperationsService()
        let file = try ops.createFile(template: .txt, in: left)

        let app = AppModel()
        app.dualPaneEnabled = true
        app.primaryPane.currentURL = left
        app.secondaryPane.currentURL = right
        app.primaryPane.selectedURLs = [file]
        app.activatePane(.primary)
        XCTAssertEqual(Array(app.activePane.selectedURLs), [file])

        app.copyToClipboard(Array(app.activePane.selectedURLs), cut: false)
        XCTAssertEqual(app.fileClipboard?.urls, [file])

        app.activatePane(.secondary)
        XCTAssertEqual(app.activePane.currentURL, right)
        try ops.copy(items: app.fileClipboard!.urls, to: app.activePane.currentURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent(file.lastPathComponent).path))
    }

    func testTransferBetweenPanesUsesActiveSelectionAndOtherPaneAsDestination() throws {
        let left = URL(fileURLWithPath: "/tmp/left-\(UUID().uuidString)")
        let right = URL(fileURLWithPath: "/tmp/right-\(UUID().uuidString)")
        let leftFile = left.appendingPathComponent("a.txt")
        let rightFile = right.appendingPathComponent("b.txt")

        let app = AppModel()
        app.dualPaneEnabled = true
        app.primaryPane.currentURL = left
        app.secondaryPane.currentURL = right
        app.primaryPane.selectedURLs = [leftFile]
        app.secondaryPane.selectedURLs = [rightFile]

        app.activatePane(.primary)
        XCTAssertEqual(Array(app.activePane.selectedURLs), [leftFile])
        XCTAssertEqual(app.inactivePane.currentURL, right)

        app.activatePane(.secondary)
        XCTAssertEqual(Array(app.activePane.selectedURLs), [rightFile])
        XCTAssertEqual(app.inactivePane.currentURL, left)
    }

    func testSearchTargetsActivePaneDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchPane-\(UUID().uuidString)", isDirectory: true)
        let left = root.appendingPathComponent("left", isDirectory: true)
        let right = root.appendingPathComponent("right", isDirectory: true)
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("L".utf8).write(to: left.appendingPathComponent("only-left.txt"))
        try Data("R".utf8).write(to: right.appendingPathComponent("only-right.txt"))

        let app = AppModel()
        app.dualPaneEnabled = true
        app.primaryPane.currentURL = left
        app.secondaryPane.currentURL = right
        app.activatePane(.secondary)

        let results = try app.searchService.search(query: "only", in: app.activePane.currentURL)
        XCTAssertEqual(results.map(\.name), ["only-right.txt"])

        var tab = app.selectedTab
        tab.searchQuery = "only"
        tab.searchResults = results
        tab.searchPaneID = .secondary
        app.selectedTab = tab
        XCTAssertTrue(app.selectedTab.hasActiveSearch)
        XCTAssertEqual(app.selectedTab.searchPaneID, .secondary)
    }
}

private extension URL {
    func withDirectoryCreated() throws -> URL {
        try FileManager.default.createDirectory(at: self, withIntermediateDirectories: true)
        return self
    }
}
