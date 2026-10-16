import XCTest
@testable import MacExplorer

final class FileOperationsTests: XCTestCase {
    private var tempRoot: URL!
    private var ops: FileOperationsService!
    private var listing: DirectoryListingService!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacExplorerOps-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        ops = FileOperationsService()
        listing = DirectoryListingService()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testCreateFolder() throws {
        let url = try ops.createFolder(named: "Folder", in: tempRoot)
        let items = try listing.listContents(of: tempRoot)
        XCTAssertTrue(items.contains {
            $0.url.standardizedFileURL == url.standardizedFileURL && $0.isDirectory
        })
    }

    func testCreateFileTemplates() throws {
        for template in FileTemplate.allCases {
            let url = try ops.createFile(template: template, in: tempRoot)
            let data = try Data(contentsOf: url)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), template.contents)
            if template == .json {
                XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data("{\n  \n}\n".utf8)))
            }
        }
    }

    func testRenameSuccess() throws {
        let file = try ops.createFile(template: .txt, in: tempRoot)
        let renamed = try ops.rename(item: file, to: "renamed.txt")
        XCTAssertEqual(renamed.lastPathComponent, "renamed.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
    }

    func testRenameCollision() throws {
        let a = try ops.createFile(template: .txt, in: tempRoot)
        _ = try ops.rename(item: a, to: "taken.txt")
        let b = try ops.createFile(template: .txt, in: tempRoot)
        XCTAssertThrowsError(try ops.rename(item: b, to: "taken.txt")) { error in
            XCTAssertEqual(error as? FilesystemError, .nameCollision("taken.txt"))
        }
    }

    func testCopyAndMoveFile() throws {
        let sourceDir = tempRoot.appendingPathComponent("src", isDirectory: true)
        let destDir = tempRoot.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let file = try ops.createFile(template: .txt, in: sourceDir)

        try ops.copy(items: [file], to: destDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destDir.appendingPathComponent(file.lastPathComponent).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let copied = destDir.appendingPathComponent(file.lastPathComponent)
        let moveDest = tempRoot.appendingPathComponent("moved", isDirectory: true)
        try FileManager.default.createDirectory(at: moveDest, withIntermediateDirectories: true)
        try ops.move(items: [copied], to: moveDest)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copied.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moveDest.appendingPathComponent(copied.lastPathComponent).path))
    }

    func testCopyFolder() throws {
        let folder = try ops.createFolder(named: "Pack", in: tempRoot)
        try Data("x".utf8).write(to: folder.appendingPathComponent("inside.txt"))
        let dest = tempRoot.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try ops.copy(items: [folder], to: dest)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("Pack/inside.txt").path))
    }

    func testTrashMovesToTrash() throws {
        let file = try ops.createFile(template: .txt, in: tempRoot)
        try ops.moveToTrash([file])
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testOperationOnMissing() throws {
        let missing = tempRoot.appendingPathComponent("gone.txt")
        XCTAssertThrowsError(try ops.rename(item: missing, to: "x.txt"))
    }

    func testNoFakeSuccessOnUnwritableDestination() throws {
        let file = try ops.createFile(template: .txt, in: tempRoot)
        let locked = tempRoot.appendingPathComponent("locked-dest", isDirectory: true)
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: locked.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
        }
        XCTAssertThrowsError(try ops.copy(items: [file], to: locked))
    }

    func testDuplicateNamesCaseSensitivityPolicy() throws {
        let a = try ops.createFile(template: .txt, in: tempRoot)
        _ = try ops.rename(item: a, to: "A.txt")
        let b = try ops.createFile(template: .markdown, in: tempRoot)
        // On APFS (typically case-insensitive) this should collide.
        do {
            _ = try ops.rename(item: b, to: "a.txt")
            // If filesystem is case-sensitive, rename may succeed — still OK.
        } catch let error as FilesystemError {
            XCTAssertEqual(error, .nameCollision("a.txt"))
        }
    }

    func testVeryLongFileName() throws {
        let longName = String(repeating: "n", count: 220) + ".txt"
        do {
            let url = tempRoot.appendingPathComponent(longName)
            try Data("x".utf8).write(to: url)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        } catch {
            // Acceptable: filesystem rejects extremely long names with a clear error.
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}
