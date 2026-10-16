import XCTest
@testable import MacExplorer

final class DirectoryListingTests: XCTestCase {
    private var tempRoot: URL!
    private var service: DirectoryListingService!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacExplorerListing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        service = DirectoryListingService(includeHiddenFiles: false)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testListEmpty() throws {
        let items = try service.listContents(of: tempRoot)
        XCTAssertTrue(items.isEmpty)
    }

    func testListNestedFileVsDirectory() throws {
        let folder = tempRoot.appendingPathComponent("Sub", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = tempRoot.appendingPathComponent("a.txt")
        try Data("hi".utf8).write(to: file)

        let items = try service.listContents(of: tempRoot)
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains { $0.name == "Sub" && $0.isDirectory })
        XCTAssertTrue(items.contains { $0.name == "a.txt" && !$0.isDirectory })
    }

    func testListUnicode() throws {
        let name = "cafè-📁.txt"
        let file = tempRoot.appendingPathComponent(name)
        try Data("x".utf8).write(to: file)
        let items = try service.listContents(of: tempRoot)
        XCTAssertTrue(items.contains { $0.name == name })
    }

    func testListHiddenPolicy() throws {
        let hidden = tempRoot.appendingPathComponent(".secret")
        try Data("x".utf8).write(to: hidden)
        let visible = tempRoot.appendingPathComponent("visible.txt")
        try Data("y".utf8).write(to: visible)

        let withoutHidden = try service.listContents(of: tempRoot)
        XCTAssertFalse(withoutHidden.contains { $0.name == ".secret" })
        XCTAssertTrue(withoutHidden.contains { $0.name == "visible.txt" })

        let withHidden = try DirectoryListingService(includeHiddenFiles: true).listContents(of: tempRoot)
        XCTAssertTrue(withHidden.contains { $0.name == ".secret" })
    }

    func testSortByName() throws {
        try Data().write(to: tempRoot.appendingPathComponent("b.txt"))
        try Data().write(to: tempRoot.appendingPathComponent("a.txt"))
        let items = try service.listContents(of: tempRoot, sortKey: .name, ascending: true)
        XCTAssertEqual(items.map(\.name), ["a.txt", "b.txt"])
    }

    func testSortBySize() throws {
        try Data(repeating: 1, count: 10).write(to: tempRoot.appendingPathComponent("big.bin"))
        try Data(repeating: 1, count: 2).write(to: tempRoot.appendingPathComponent("small.bin"))
        let items = try service.listContents(of: tempRoot, sortKey: .size, ascending: true)
        XCTAssertEqual(items.map(\.name), ["small.bin", "big.bin"])
    }

    func testMissingPath() {
        let missing = tempRoot.appendingPathComponent("nope", isDirectory: true)
        XCTAssertThrowsError(try service.listContents(of: missing)) { error in
            XCTAssertEqual(error as? FilesystemError, .missingPath("nope"))
        }
    }

    func testPermissionDenied() throws {
        let locked = tempRoot.appendingPathComponent("locked", isDirectory: true)
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
        }
        XCTAssertThrowsError(try service.listContents(of: locked)) { error in
            guard case FilesystemError.permissionDenied = error else {
                return XCTFail("Expected permissionDenied, got \(error)")
            }
        }
    }

    func testMetadataSizeDates() throws {
        let file = tempRoot.appendingPathComponent("meta.txt")
        try Data("hello".utf8).write(to: file)
        let item = try service.makeItem(from: file)
        XCTAssertEqual(item.fileSize, 5)
        XCTAssertNotNil(item.contentModificationDate)
        XCTAssertFalse(item.isDirectory)
    }

    func testSymlinkHandlingShowsLinkFlag() throws {
        let target = tempRoot.appendingPathComponent("target.txt")
        try Data("t".utf8).write(to: target)
        let link = tempRoot.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let item = try service.makeItem(from: link)
        XCTAssertTrue(item.isSymbolicLink)
    }

    func testLargeDirectoryCapSmoke() throws {
        for i in 0..<2000 {
            try Data().write(to: tempRoot.appendingPathComponent("f\(i).txt"))
        }
        let items = try service.listContents(of: tempRoot)
        XCTAssertEqual(items.count, 2000)
    }
}
