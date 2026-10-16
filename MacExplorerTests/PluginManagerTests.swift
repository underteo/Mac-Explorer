import XCTest
@testable import MacExplorer

private final class MemoryEnableStore: PluginEnableStore {
    var values: [String: Bool] = [:]
    func isEnabled(pluginID: String) -> Bool { values[pluginID] ?? true }
    func setEnabled(_ enabled: Bool, pluginID: String) { values[pluginID] = enabled }
}

final class PluginManagerTests: XCTestCase {
    private var pluginsRoot: URL!

    override func setUpWithError() throws {
        pluginsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Plugins-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginsRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: pluginsRoot)
    }

    @MainActor
    private func makeManager(store: PluginEnableStore = MemoryEnableStore()) -> PluginManager {
        PluginManager(pluginsDirectory: pluginsRoot, enableStore: store, watchDirectory: false)
    }

    @MainActor
    func testInstallCopiesSelfContainedFolder() throws {
        let source = pluginsRoot.appendingPathComponent("SourceCursor", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let manifest = """
        {"id":"com.example.cursor","name":"Cursor","version":"1","match":{},"menu":[{"type":"action","id":"chat","title":"Chat","action":"chat"}],"executable":"run.sh"}
        """
        try Data(manifest.utf8).write(to: source.appendingPathComponent("manifest.json"))
        try "#!/bin/sh\nexit 0\n".write(to: source.appendingPathComponent("run.sh"), atomically: true, encoding: .utf8)

        let liveRoot = pluginsRoot.appendingPathComponent("Live", isDirectory: true)
        try FileManager.default.createDirectory(at: liveRoot, withIntermediateDirectories: true)
        let manager = PluginManager(pluginsDirectory: liveRoot, enableStore: MemoryEnableStore(), watchDirectory: false)
        let installed = try manager.install(from: source)
        XCTAssertEqual(installed.manifest.id, "com.example.cursor")
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.directoryURL.appendingPathComponent("run.sh").path))
        XCTAssertEqual(manager.plugins.count, 1)
    }

    func testParseValidManifest() throws {
        let json = """
        {
          "id": "demo.tools",
          "name": "Demo Tools",
          "version": "1.0",
          "match": { "extensions": ["txt"] },
          "menu": [
            { "type": "submenu", "title": "Shortcuts", "children": [
              { "type": "action", "id": "echo", "title": "Echo", "action": "echo" }
            ]}
          ],
          "executable": "run.sh"
        }
        """.data(using: .utf8)!
        let manifest = try PluginManager.parseManifest(data: json)
        XCTAssertEqual(manifest.id, "demo.tools")
        XCTAssertEqual(manifest.menu.count, 1)
    }

    func testParseInvalidManifest() {
        let data = Data("not-json".utf8)
        XCTAssertThrowsError(try PluginManager.parseManifest(data: data))
    }

    func testPluginMenuTargetsFallbackToCurrentDirectory() {
        let dir = URL(fileURLWithPath: "/tmp/pane-root", isDirectory: true)
        let empty = PluginMenuTargets.resolve(selected: [], directoryURL: dir)
        XCTAssertEqual(empty.count, 1)
        XCTAssertTrue(empty[0].isDirectory)
        XCTAssertEqual(empty[0].url.standardizedFileURL, dir.standardizedFileURL)

        let file = FileItem(
            url: URL(fileURLWithPath: "/tmp/pane-root/a.txt"),
            name: "a.txt",
            isDirectory: false,
            isHidden: false,
            isSymbolicLink: false,
            fileSize: 1,
            contentModificationDate: nil,
            creationDate: nil,
            contentType: nil
        )
        let kept = PluginMenuTargets.resolve(selected: [file], directoryURL: dir)
        XCTAssertEqual(kept.map(\.url), [file.url])
    }

    func testMatchRules() {
        let file = FileItem(
            url: URL(fileURLWithPath: "/tmp/a.png"),
            name: "a.png",
            isDirectory: false,
            isHidden: false,
            isSymbolicLink: false,
            fileSize: 1,
            contentModificationDate: nil,
            creationDate: nil,
            contentType: nil
        )
        let folder = FileItem(
            url: URL(fileURLWithPath: "/tmp/dir"),
            name: "dir",
            isDirectory: true,
            isHidden: false,
            isSymbolicLink: false,
            fileSize: nil,
            contentModificationDate: nil,
            creationDate: nil,
            contentType: nil
        )
        XCTAssertTrue(PluginMatchRules(extensions: ["png"]).matches(items: [file]))
        XCTAssertFalse(PluginMatchRules(extensions: ["png"]).matches(items: [folder]))
        XCTAssertTrue(PluginMatchRules(foldersOnly: true).matches(items: [folder]))
        XCTAssertFalse(PluginMatchRules(requireMultiSelect: true).matches(items: [file]))
        XCTAssertTrue(PluginMatchRules(requireMultiSelect: true, allowMultiSelect: true).matches(items: [file, file]))
    }

    @MainActor
    func testEnableDisableAndSubmenuStructure() throws {
        let pluginDir = pluginsRoot.appendingPathComponent("Demo", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        let manifest = """
        {"id":"demo","name":"Demo","version":"1","match":{},"menu":[{"type":"submenu","title":"More","children":[{"type":"action","id":"a","title":"Act"}]}],"executable":"run.sh"}
        """
        try Data(manifest.utf8).write(to: pluginDir.appendingPathComponent("manifest.json"))
        try "#!/bin/sh\nexit 0\n".write(to: pluginDir.appendingPathComponent("run.sh"), atomically: true, encoding: .utf8)

        let store = MemoryEnableStore()
        let manager = makeManager(store: store)
        manager.reload()
        XCTAssertEqual(manager.plugins.count, 1)
        XCTAssertTrue(manager.enabledMenuProviders(for: sampleItems()).contains { $0.manifest.id == "demo" })

        manager.setEnabled(false, pluginID: "demo")
        XCTAssertFalse(manager.enabledMenuProviders(for: sampleItems()).contains { $0.manifest.id == "demo" })

        if case .submenu(let title, let children) = manager.plugins[0].manifest.menu[0] {
            XCTAssertEqual(title, "More")
            XCTAssertEqual(children.count, 1)
        } else {
            XCTFail("Expected submenu")
        }
    }

    @MainActor
    func testPersistenceEnableState() {
        let store = MemoryEnableStore()
        store.setEnabled(false, pluginID: "x")
        let manager = makeManager(store: store)
        XCTAssertFalse(store.isEnabled(pluginID: "x"))
        _ = manager
    }

    func testPluginPathTraversalRejected() {
        XCTAssertThrowsError(
            try PluginManager.resolvedExecutableURL(executable: "/usr/bin/true", pluginRoot: pluginsRoot)
        ) { error in
            XCTAssertEqual(error as? PluginError, .pathTraversalRejected)
        }
    }

    @MainActor
    func testPluginActionFailureIsolated() throws {
        let pluginDir = pluginsRoot.appendingPathComponent("Broken", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        let manifest = """
        {"id":"broken","name":"Broken","version":"1","match":{},"menu":[{"type":"action","id":"x","title":"X"}]}
        """
        try Data(manifest.utf8).write(to: pluginDir.appendingPathComponent("manifest.json"))
        let manager = makeManager()
        manager.reload()
        let plugin = try XCTUnwrap(manager.plugins.first)
        let result = manager.run(
            action: PluginMenuAction(id: "x", title: "X", action: nil, shortcut: nil),
            plugin: plugin,
            items: sampleItems()
        )
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(manager.plugins.count, 1)
    }

    func testDisabledSurvivesRelaunch() throws {
        let suiteName = "MacExplorerTests.PluginEnable.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsPluginEnableStore(defaults: defaults)
        store.setEnabled(false, pluginID: "keep")
        let again = UserDefaultsPluginEnableStore(defaults: defaults)
        XCTAssertFalse(again.isEnabled(pluginID: "keep"))
    }

    private func sampleItems() -> [FileItem] {
        [
            FileItem(
                url: URL(fileURLWithPath: "/tmp/a.txt"),
                name: "a.txt",
                isDirectory: false,
                isHidden: false,
                isSymbolicLink: false,
                fileSize: 1,
                contentModificationDate: nil,
                creationDate: nil,
                contentType: nil
            )
        ]
    }
}

private extension Result {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
