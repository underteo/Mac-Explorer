import XCTest
@testable import MacExplorer

@MainActor
final class ExplorerWorkflowTests: XCTestCase {
    private var root: URL!
    private var ops: FileOperationsService!
    private var listing: DirectoryListingService!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Workflow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        ops = FileOperationsService()
        listing = DirectoryListingService()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testCreateRenameRefreshListing() throws {
        let file = try ops.createFile(template: .markdown, in: root)
        let renamed = try ops.rename(item: file, to: "notes.md")
        let items = try listing.listContents(of: root)
        XCTAssertTrue(items.contains { $0.name == "notes.md" })
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
    }

    func testUniqueFilenamesWhenUntitledExists() throws {
        _ = try ops.createFile(template: .txt, in: root)
        let second = try ops.createFile(template: .txt, in: root)
        XCTAssertEqual(second.lastPathComponent, "Untitled 2.txt")
        let third = try ops.createFile(template: .txt, in: root)
        XCTAssertEqual(third.lastPathComponent, "Untitled 3.txt")
    }

    func testCopyCollisionThenOverwrite() throws {
        let left = root.appendingPathComponent("L", isDirectory: true)
        let right = root.appendingPathComponent("R", isDirectory: true)
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
        let file = try ops.createFile(template: .csv, in: left)
        try ops.copy(items: [file], to: right)
        XCTAssertThrowsError(try ops.copy(items: [file], to: right, overwrite: false))
        try ops.copy(items: [file], to: right, overwrite: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent(file.lastPathComponent).path))
    }

    func testTrashThenMissingPathError() throws {
        let file = try ops.createFile(template: .html, in: root)
        try ops.moveToTrash([file])
        XCTAssertThrowsError(try listing.listContents(of: file))
    }

    func testPaneControllerReloadPopulatesItems() async throws {
        _ = try ops.createFolder(named: "A", in: root)
        _ = try ops.createFile(template: .txt, in: root)
        var pane = PaneState(currentURL: root)
        await PaneController.reload(&pane, using: listing)
        XCTAssertNil(pane.errorMessage)
        XCTAssertEqual(pane.items.count, 2)
        XCTAssertFalse(pane.isLoading)
    }

    func testPaneControllerNavigateRecordsHistory() async throws {
        let child = try ops.createFolder(named: "Child", in: root)
        var pane = PaneState(currentURL: root)
        await PaneController.reload(&pane, using: listing)
        await PaneController.navigate(&pane, to: child, using: listing)
        XCTAssertEqual(pane.currentURL.standardizedFileURL, child.standardizedFileURL)
        XCTAssertTrue(pane.history.canGoBack)
        await PaneController.goBack(&pane, using: listing)
        XCTAssertEqual(pane.currentURL.standardizedFileURL, root.standardizedFileURL)
    }

    func testSearchAfterCreate() throws {
        _ = try ops.createFile(template: .txt, in: root)
        let named = root.appendingPathComponent("Report Final.txt")
        try Data("x".utf8).write(to: named)
        let results = try DirectorySearchService(listing: listing).search(query: "report", in: root)
        XCTAssertEqual(results.map(\.name), ["Report Final.txt"])
    }

    func testDualPaneCopyPreservesSource() async throws {
        let left = root.appendingPathComponent("left", isDirectory: true)
        let right = root.appendingPathComponent("right", isDirectory: true)
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
        let file = try ops.createFile(template: .json, in: left)
        try await ops.copyWithProgress(
            items: [file],
            to: right,
            overwrite: false,
            progress: { _ in },
            isCancelled: { false }
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent(file.lastPathComponent).path))
    }
}
