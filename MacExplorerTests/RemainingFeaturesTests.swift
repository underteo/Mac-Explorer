import XCTest
@testable import MacExplorer

@MainActor
final class RemainingFeaturesTests: XCTestCase {
    func testRecentsRecordAndLimit() {
        let suite = "MacExplorerTests.Recents.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RecentsStore(defaults: defaults)
        for i in 0..<15 {
            store.record(URL(fileURLWithPath: "/tmp/r\(i)", isDirectory: true))
        }
        XCTAssertEqual(store.items.count, 12)
        XCTAssertEqual(store.items.first?.name, "r14")
    }

    func testDuplicateCreatesSibling() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let ops = FileOperationsService()
        let original = try ops.createFile(template: .txt, in: root)
        let copy = try ops.duplicate(original)
        XCTAssertNotEqual(original.path, copy.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.path))
    }

    func testGetInfoForFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Info-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let ops = FileOperationsService()
        let file = try ops.createFile(template: .markdown, in: root)
        let info = try ops.makeInfo(for: file)
        XCTAssertEqual(info.name, file.lastPathComponent)
        XCTAssertFalse(info.isDirectory)
        XCTAssertFalse(info.sizeLabel.isEmpty)
        XCTAssertEqual(info.path, file.path)
    }

    func testClipboardCutFlag() {
        let app = AppModel()
        let url = URL(fileURLWithPath: "/tmp/a.txt")
        app.copyToClipboard([url], cut: true)
        XCTAssertEqual(app.fileClipboard?.isCut, true)
        XCTAssertEqual(app.fileClipboard?.urls, [url])
        app.clearClipboard()
        XCTAssertNil(app.fileClipboard)
    }

    func testShowHiddenToggleMutatesFilesystem() {
        let app = AppModel()
        XCTAssertFalse(app.filesystem.includeHiddenFiles)
        app.showHiddenFiles = true
        XCTAssertTrue(app.filesystem.includeHiddenFiles)
    }

    func testPasteCopyWorkflow() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Paste-\(UUID().uuidString)", isDirectory: true)
        let src = root.appendingPathComponent("src", isDirectory: true)
        let dst = root.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let ops = FileOperationsService()
        let file = try ops.createFile(template: .csv, in: src)
        try ops.copy(items: [file], to: dst)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent(file.lastPathComponent).path))
    }
}
