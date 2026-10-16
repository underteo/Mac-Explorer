import SwiftUI
import AppKit
import Combine

struct ExplorerRootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showTrashConfirm = false
    @State private var showiCloudTrashConfirm = false
    @State private var showEmptyTrashConfirm = false
    @State private var showExtensionChangeConfirm = false
    @State private var pendingRenameName: String?
    @State private var renameTarget: FileItem?
    @State private var renameText = ""
    @State private var collisionAlert: String?
    @State private var pendingCollision: PendingCollision?
    @State private var showTagsPopover = false
    @State private var showMorePopover = false

    var body: some View {
        rootChrome
            .modifier(ExplorerCommandReceiver { name, object in
                handleCommand(name, object: object)
            })
            .modifier(ExplorerDialogs(
                showTrashConfirm: $showTrashConfirm,
                showiCloudTrashConfirm: $showiCloudTrashConfirm,
                showEmptyTrashConfirm: $showEmptyTrashConfirm,
                showExtensionChangeConfirm: $showExtensionChangeConfirm,
                collisionAlert: $collisionAlert,
                pendingCollision: $pendingCollision,
                lastErrorMessage: $app.lastErrorMessage,
                onTrash: { Task { await performTrash() } },
                onEmptyTrash: { Task { await performEmptyTrash() } },
                onConfirmExtensionChange: {
                    if let name = pendingRenameName {
                        Task { await commitRename(to: name) }
                    }
                },
                onOverwrite: { Task { await resolveCollision(overwrite: true) } }
            ))
            .sheet(item: infoSheetBinding) { item in
                GetInfoSheet(info: item.summary) {
                    app.infoSummary = nil
                }
            }
            .overlay(alignment: .bottom) {
                if let progress = app.transferProgress {
                    TransferProgressBanner(progress: progress) {
                        app.transferProgress?.isCancelled = true
                    }
                    .padding()
                }
            }
    }

    private var rootChrome: some View {
        // Path/tabs belong in the detail column. Putting them above NavigationSplitView
        // made the detail reserve a second empty toolbar band (looked like dead space
        // above Nome/Data/…).
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                tabBar
                pathBar
                detailContent
            }
        }
        .navigationTitle("")
        .toolbar { toolbarContent }
        .searchable(text: bindingSearchQuery, prompt: Text(L10n.tr("search.prompt")))
        .onSubmit(of: .search) {
            Task { await runSearch() }
        }
        .onChange(of: app.selectedTab.searchQuery) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                var tab = app.selectedTab
                tab.searchResults = []
                tab.isSearching = false
                app.selectedTab = tab
            } else {
                Task { await runSearch() }
            }
        }
        .onChange(of: app.activePaneID) { _, _ in
            if app.selectedTab.hasActiveSearch {
                Task { await runSearch() }
            }
        }
        .onChange(of: settings.keepFoldersOnTopWhenSortingByName) { _, _ in
            Task {
                await refreshPrimary()
                if app.dualPaneEnabled { await refreshSecondary() }
            }
        }
        .onChange(of: settings.keepFoldersOnTopOnDesktop) { _, _ in
            Task {
                await refreshPrimary()
                if app.dualPaneEnabled { await refreshSecondary() }
            }
        }
        .task {
            await refreshPrimary()
            if app.dualPaneEnabled {
                await refreshSecondary()
            }
        }
    }

    private var infoSheetBinding: Binding<InfoSheetItem?> {
        Binding(
            get: { app.infoSummary.map { InfoSheetItem(summary: $0) } },
            set: { app.infoSummary = $0?.summary }
        )
    }

    func handleCommand(_ name: Notification.Name, object: Any?) {
        switch name {
        case .explorerNewTab:
            app.newTab()
            Task { await refreshPrimary() }
        case .explorerGoBack:
            guard !app.isEditingText else { return }
            Task { await goBackPrimary() }
        case .explorerGoForward:
            guard !app.isEditingText else { return }
            Task { await goForwardPrimary() }
        case .explorerGoUp:
            guard !app.isEditingText else { return }
            Task { await goUpPrimary() }
        case .explorerRefresh:
            Task {
                await refreshPrimary()
                if app.dualPaneEnabled { await refreshSecondary() }
            }
        case .explorerOpenFolder:
            openFolderPanel()
        case .explorerPathInvalid:
            if let message = object as? String {
                app.lastErrorMessage = message
            }
        case .explorerNewFolder:
            guard !app.isEditingText else { return }
            createNewFolder()
        case .explorerNewFile:
            guard !app.isEditingText else { return }
            if let raw = object as? String, let template = FileTemplate(rawValue: raw) {
                createNewFile(template)
            }
        case .explorerCopy:
            if copyFocusedTextOrSelection(cut: false) { return }
            copySelection(cut: false)
        case .explorerCut:
            if copyFocusedTextOrSelection(cut: true) { return }
            copySelection(cut: true)
        case .explorerPaste:
            if pasteIntoFocusedTextField() { return }
            let destination = object as? URL
            Task { await pasteClipboard(to: destination) }
        case .explorerSelectAll:
            if selectAllFocusedText() { return }
            selectAllFilesInActivePane()
        case .explorerDuplicate:
            guard !app.isEditingText else { return }
            Task { await duplicateSelection() }
        case .explorerCopyPath:
            copySelectionPaths()
        case .explorerGetInfo:
            showGetInfo()
        case .explorerTrash:
            guard !app.isEditingText else { return }
            requestTrash()
        case .explorerToggleHidden:
            app.showHiddenFiles.toggle()
            Task {
                await refreshPrimary()
                if app.dualPaneEnabled { await refreshSecondary() }
            }
        case .explorerToggleDualPane:
            app.dualPaneEnabled.toggle()
            if app.dualPaneEnabled {
                Task { await refreshSecondary() }
            }
        case .explorerInstallPlugin:
            app.pluginManager.presentInstallPanel()
        case .explorerReloadPlugins:
            app.pluginManager.reload()
        case .explorerRevealPlugins:
            app.pluginManager.revealPluginsFolder()
        case .explorerPluginInstallFailed:
            if let message = object as? String {
                app.lastErrorMessage = message
            }
        case .explorerCompress:
            guard !app.isEditingText else { return }
            Task { await compressSelection() }
        case .explorerMakeAlias:
            guard !app.isEditingText else { return }
            Task { await makeAliasSelection() }
        case .explorerQuickLook:
            guard !app.isEditingText else { return }
            quickLookSelection()
        case .explorerOpenInNewPane:
            guard !app.isEditingText else { return }
            Task { await openInOtherPaneFromSelection() }
        case .explorerTerminalTab:
            openTerminalFromSelection(newTab: true)
        case .explorerTerminalWindow:
            openTerminalFromSelection(newTab: false)
        case .explorerCustomizeInFinder:
            let url = selectedURLs().first ?? app.activePane.currentURL
            FinderTags.revealFinderInfo(for: url)
        case .explorerFolderActionsSetup:
            app.fileOperations.openFolderActionsSetup()
        case .explorerShowViewOptions:
            openSettingsWindow()
        default:
            break
        }
    }

    private var bindingSearchQuery: Binding<String> {
        Binding(
            get: { app.selectedTab.searchQuery },
            set: { value in
                var tab = app.selectedTab
                tab.searchQuery = value
                app.selectedTab = tab
            }
        )
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(app.tabs) { tab in
                TabChip(
                    title: tab.pane.currentURL.lastPathComponent,
                    isSelected: tab.id == app.selectedTabID,
                    onSelect: {
                        app.selectedTabID = tab.id
                        Task { await refreshPrimary() }
                    },
                    onClose: {
                        app.closeTab(tab.id)
                    }
                )
            }
            Button {
                app.newTab()
                Task { await refreshPrimary() }
            } label: {
                Image(systemName: "plus")
            }
            .help(L10n.tr("command.new_tab"))
            .accessibilityLabel(L10n.tr("command.new_tab"))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var pathBar: some View {
        // Selection actions live here (not in the window toolbar) so Share/Tags/More
        // never reshuffle with view/sort capsules when the selection or dual-pane changes.
        HStack(spacing: 10) {
            PathLocationBar(
                url: app.activePane.currentURL,
                onNavigate: { url in
                    Task { await navigateActivePane(to: url) }
                },
                onEditingChanged: { editing in
                    app.isEditingText = editing
                }
            )
            .frame(maxWidth: .infinity)

            ExplorerSelectionActionsBar(
                selectedURLs: selectedURLs(),
                tagsPopoverTitle: tagsPopoverTitle,
                showTagsPopover: $showTagsPopover,
                showMorePopover: $showMorePopover,
                onShare: { presentSharePicker() },
                onRefresh: { Task { await refreshActivePanes() } },
                onNewFolder: { createNewFolder() },
                onCompress: { Task { await compressSelection() } },
                onMakeAlias: { Task { await makeAliasSelection() } },
                onQuickLook: { quickLookSelection() }
            )
        }
        .padding(.trailing, 8)
        .background(.bar)
        .id(app.activePaneID)
    }

    @ViewBuilder
    private var detailContent: some View {
        if app.dualPaneEnabled {
            HSplitView {
                PaneBrowserView(
                    pane: primaryPaneBinding,
                    isPrimary: true,
                    onOpen: { item in Task { await openItem(item, primary: true) } },
                    onFocusDirectory: { url, urls in Task { await focusDirectory(url, primary: true, restoring: urls) } },
                    onTrash: { requestTrash() },
                    onRename: { beginRename($0) },
                    onRefresh: { Task { await refreshPrimary() } },
                    onCreated: { url in Task { await selectAndBeginRename(url, primary: true) } },
                    onPaste: { Task { await pasteClipboard(to: app.primaryPane.currentURL) } },
                    onActivate: { app.activatePane(.primary) },
                    onOpenInNewPane: { url in Task { await openInOtherPane(url) } },
                    onShowViewOptions: { openSettingsWindow() },
                    renameURL: renameTarget?.url,
                    renameText: $renameText,
                    onCommitRename: { Task { await performRename() } },
                    onCancelRename: { cancelRename() }
                )
                PaneBrowserView(
                    pane: secondaryPaneBinding,
                    isPrimary: false,
                    onOpen: { item in Task { await openItem(item, primary: false) } },
                    onFocusDirectory: { url, urls in Task { await focusDirectory(url, primary: false, restoring: urls) } },
                    onTrash: { requestTrash() },
                    onRename: { beginRename($0) },
                    onRefresh: { Task { await refreshSecondary() } },
                    onCreated: { url in Task { await selectAndBeginRename(url, primary: false) } },
                    onPaste: { Task { await pasteClipboard(to: app.secondaryPane.currentURL) } },
                    onActivate: { app.activatePane(.secondary) },
                    onOpenInNewPane: { url in Task { await openInOtherPane(url) } },
                    onShowViewOptions: { openSettingsWindow() },
                    renameURL: renameTarget?.url,
                    renameText: $renameText,
                    onCommitRename: { Task { await performRename() } },
                    onCancelRename: { cancelRename() }
                )
            }
        } else {
            PaneBrowserView(
                pane: primaryPaneBinding,
                isPrimary: true,
                onOpen: { item in Task { await openItem(item, primary: true) } },
                onFocusDirectory: { url, urls in Task { await focusDirectory(url, primary: true, restoring: urls) } },
                onTrash: { requestTrash() },
                onRename: { beginRename($0) },
                onRefresh: { Task { await refreshPrimary() } },
                onCreated: { url in Task { await selectAndBeginRename(url, primary: true) } },
                onPaste: { Task { await pasteClipboard(to: app.primaryPane.currentURL) } },
                onActivate: { app.activatePane(.primary) },
                onOpenInNewPane: { url in Task { await openInOtherPane(url) } },
                onShowViewOptions: { openSettingsWindow() },
                renameURL: renameTarget?.url,
                renameText: $renameText,
                onCommitRename: { Task { await performRename() } },
                onCancelRename: { cancelRename() }
            )
        }
    }

    private var primaryPaneBinding: Binding<PaneState> {
        Binding(
            get: { app.primaryPane },
            set: { newValue in
                guard app.primaryPane != newValue else { return }
                app.primaryPane = newValue
            }
        )
    }

    private var secondaryPaneBinding: Binding<PaneState> {
        Binding(
            get: { app.secondaryPane },
            set: { newValue in
                guard app.secondaryPane != newValue else { return }
                app.secondaryPane = newValue
            }
        )
    }

    private var toolbarContent: some ToolbarContent {
        ExplorerToolbar(
            onGoBack: { Task { await goBackPrimary() } },
            onGoForward: { Task { await goForwardPrimary() } },
            onGoUp: { Task { await goUpPrimary() } },
            onOpenFolder: { openFolderPanel() },
            onNewFolder: { createNewFolder() },
            onRefresh: { Task { await refreshPrimary() } },
            onEmptyTrash: { requestEmptyTrash() },
            onHiddenFilesChanged: {
                Task {
                    await refreshPrimary()
                    if app.dualPaneEnabled { await refreshSecondary() }
                }
            },
            onDualPaneEnabled: { Task { await refreshSecondary() } },
            onCopyToOtherPane: { Task { await transferBetweenPanes(move: false) } },
            onMoveToOtherPane: { Task { await transferBetweenPanes(move: true) } },
            onToggleFavorite: {
                let url = app.activePane.currentURL
                if app.isFavorite(url) {
                    app.removeFavorite(url: url)
                } else {
                    _ = app.addFavorite(url)
                }
            },
            onSortKey: { key in
                applyActivePaneSortKey(key)
            },
            onToggleSortAscending: {
                toggleActivePaneSortAscending()
            }
        )
    }

    private func applyActivePaneSortKey(_ key: FileSortKey) {
        if app.activePaneID == .secondary, app.dualPaneEnabled {
            var pane = app.secondaryPane
            pane.sortKey = key
            app.secondaryPane = pane
            Task { await refreshSecondary() }
        } else {
            var pane = app.primaryPane
            pane.sortKey = key
            app.primaryPane = pane
            Task { await refreshPrimary() }
        }
    }

    private func toggleActivePaneSortAscending() {
        if app.activePaneID == .secondary, app.dualPaneEnabled {
            var pane = app.secondaryPane
            pane.sortAscending.toggle()
            app.secondaryPane = pane
            Task { await refreshSecondary() }
        } else {
            var pane = app.primaryPane
            pane.sortAscending.toggle()
            app.primaryPane = pane
            Task { await refreshPrimary() }
        }
    }

    private var tagsPopoverTitle: String {
        let items = app.activePane.selectedItems
        if items.count == 1 {
            return L10n.tr("tags.assign_title %@", items[0].name)
        }
        if items.count > 1 {
            return L10n.tr("tags.assign_title_multiple %lld", items.count)
        }
        return L10n.tr("tags.assign_title %@", app.activePane.currentURL.lastPathComponent)
    }

    private func refreshActivePanes() async {
        await refreshPrimary()
        if app.dualPaneEnabled { await refreshSecondary() }
    }

    private func presentSharePicker() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible),
              let content = window.contentView else { return }
        let picker = NSSharingServicePicker(items: urls)
        // Anchor near the trailing toolbar edge (Finder-like).
        let anchor = NSRect(
            x: max(0, content.bounds.maxX - 160),
            y: max(0, content.bounds.maxY - 8),
            width: 1,
            height: 1
        )
        picker.show(relativeTo: anchor, of: content, preferredEdge: .minY)
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await openDirectory(url, primary: true)
            }
        }
    }

    /// Navigate into a directory in the current pane (Finder-like).
    /// “Open folders in tabs instead of new windows” only applies when we would open a *new window*,
    /// not to normal double-click / Open Folder navigation.
    private func openDirectory(_ url: URL, primary: Bool) async {
        await focusDirectory(url, primary: primary, restoring: [])
    }

    private func openSettingsWindow() {
        settings.openSettings(tab: .advanced)
    }

    /// Open folder in the other dual pane (enables dual-pane if needed).
    private func openInOtherPane(_ url: URL) async {
        if !app.dualPaneEnabled {
            app.dualPaneEnabled = true
            await refreshSecondary()
        }
        let intoPrimary = app.activePaneID == .secondary
        await focusDirectory(url, primary: intoPrimary, restoring: [])
    }

    private func openInOtherPaneFromSelection() async {
        let urls = selectedURLs()
        let target: URL
        if let first = urls.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir), isDir.boolValue {
                target = first
            } else {
                target = first.deletingLastPathComponent()
            }
        } else {
            target = app.activePane.currentURL
        }
        await openInOtherPane(target)
    }

    private func compressSelection() async {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        do {
            _ = try app.fileOperations.compress(urls)
            await refreshPrimary()
            if app.dualPaneEnabled { await refreshSecondary() }
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    private func makeAliasSelection() async {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        do {
            for url in urls {
                _ = try app.fileOperations.makeAlias(of: url)
            }
            await refreshPrimary()
            if app.dualPaneEnabled { await refreshSecondary() }
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    private func quickLookSelection() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        QuickLookController.shared.show(urls: urls)
    }

    private func openTerminalFromSelection(newTab: Bool) {
        let urls = selectedURLs()
        let folder: URL
        if let first = urls.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir), isDir.boolValue {
                folder = first
            } else {
                folder = first.deletingLastPathComponent()
            }
        } else {
            folder = app.activePane.currentURL
        }
        app.fileOperations.openInTerminal(folder, newTab: newTab)
    }

    /// Navigate in-pane (column view single-click). Ignores “open folders in tabs”.
    private func focusDirectory(_ url: URL, primary: Bool, restoring selection: Set<URL>) async {
        let standardized = url.standardizedFileURL
        if primary {
            if app.primaryPane.currentURL.standardizedFileURL == standardized {
                var pane = app.primaryPane
                pane.selectedURLs = selection.isEmpty ? [standardized] : selection
                app.primaryPane = pane
                return
            }
            await navigatePrimary(to: url)
            var pane = app.primaryPane
            pane.selectedURLs = selection.isEmpty ? [standardized] : selection
            app.primaryPane = pane
        } else {
            if app.secondaryPane.currentURL.standardizedFileURL == standardized {
                var pane = app.secondaryPane
                pane.selectedURLs = selection.isEmpty ? [standardized] : selection
                app.secondaryPane = pane
                return
            }
            var pane = app.secondaryPane
            await PaneController.navigate(
                &pane,
                to: url,
                using: app.filesystem,
                keepFoldersOnTop: settings.keepFoldersOnTop(directory: url, sortKey: pane.sortKey)
            )
            pane.selectedURLs = selection.isEmpty ? [standardized] : selection
            app.secondaryPane = pane
        }
    }

    private func keepFoldersOnTop(for pane: PaneState) -> Bool {
        settings.keepFoldersOnTop(directory: pane.currentURL, sortKey: pane.sortKey)
    }

    private func refreshPrimary() async {
        var pane = app.primaryPane
        await PaneController.reload(&pane, using: app.filesystem, keepFoldersOnTop: keepFoldersOnTop(for: pane))
        app.primaryPane = pane
        var tab = app.selectedTab
        tab.title = pane.currentURL.lastPathComponent
        app.selectedTab = tab
    }

    private func refreshSecondary() async {
        var pane = app.secondaryPane
        await PaneController.reload(&pane, using: app.filesystem, keepFoldersOnTop: keepFoldersOnTop(for: pane))
        app.secondaryPane = pane
    }

    private func navigatePrimary(to url: URL) async {
        var pane = app.primaryPane
        await PaneController.navigate(
            &pane,
            to: url,
            using: app.filesystem,
            keepFoldersOnTop: settings.keepFoldersOnTop(directory: url, sortKey: pane.sortKey)
        )
        app.primaryPane = pane
        var tab = app.selectedTab
        tab.title = url.lastPathComponent
        tab.searchQuery = ""
        tab.searchResults = []
        app.selectedTab = tab
        app.recordRecent(url)
    }

    private func goBackPrimary() async {
        var pane = app.primaryPane
        await PaneController.goBack(&pane, using: app.filesystem, keepFoldersOnTop: keepFoldersOnTop(for: pane))
        app.primaryPane = pane
        app.recordRecent(pane.currentURL)
    }

    private func goForwardPrimary() async {
        var pane = app.primaryPane
        await PaneController.goForward(&pane, using: app.filesystem, keepFoldersOnTop: keepFoldersOnTop(for: pane))
        app.primaryPane = pane
        app.recordRecent(pane.currentURL)
    }

    private func goUpPrimary() async {
        let current = app.primaryPane.currentURL
        let parent = current.deletingLastPathComponent()
        guard parent.path != current.path else { return }
        await navigatePrimary(to: parent)
    }

    private func createNewFolder() {
        do {
            let url = try app.fileOperations.createFolder(
                named: L10n.tr("default.new_folder"),
                in: app.primaryPane.currentURL
            )
            Task { await selectAndBeginRename(url, primary: true) }
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    private func createNewFile(_ template: FileTemplate) {
        do {
            let url = try app.fileOperations.createFile(template: template, in: app.primaryPane.currentURL)
            Task { await selectAndBeginRename(url, primary: true) }
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    /// Refresh the pane, select the new item, and start inline rename.
    private func selectAndBeginRename(_ url: URL, primary: Bool) async {
        let target = url.standardizedFileURL
        if primary {
            await refreshPrimary()
        } else {
            await refreshSecondary()
        }
        // Let the list/grid commit the new row before focusing the editor.
        try? await Task.sleep(for: .milliseconds(80))

        if primary {
            var pane = app.primaryPane
            if let item = pane.items.first(where: { $0.url.standardizedFileURL == target })
                ?? (try? app.filesystem.makeItem(from: target)) {
                pane.selectedURLs = [item.url]
                app.primaryPane = pane
                beginRename(item)
            }
        } else {
            var pane = app.secondaryPane
            if let item = pane.items.first(where: { $0.url.standardizedFileURL == target })
                ?? (try? app.filesystem.makeItem(from: target)) {
                pane.selectedURLs = [item.url]
                app.secondaryPane = pane
                beginRename(item)
            }
        }
    }

    private func selectedURLs() -> [URL] {
        Array(app.activePane.selectedURLs)
    }

    /// When the path bar / rename field is focused, ⌘C/⌘X must edit text — not the file clipboard.
    /// With no text selection, copy the whole field (address-bar style).
    @discardableResult
    private func copyFocusedTextOrSelection(cut: Bool) -> Bool {
        guard app.isEditingText || focusedTextView() != nil else { return false }
        if let textView = focusedTextView() {
            let range = textView.selectedRange()
            if range.length > 0 {
                if cut {
                    textView.cut(nil)
                } else {
                    textView.copy(nil)
                }
                return true
            }
            let full = textView.string
            guard !full.isEmpty else { return true }
            if cut {
                textView.selectAll(nil)
                textView.cut(nil)
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(full, forType: .string)
            }
            return true
        }
        let selector: Selector = cut ? #selector(NSText.cut(_:)) : #selector(NSText.copy(_:))
        return NSApp.sendAction(selector, to: nil, from: nil)
    }

    @discardableResult
    private func pasteIntoFocusedTextField() -> Bool {
        guard app.isEditingText || focusedTextView() != nil else { return false }
        if let textView = focusedTextView() {
            textView.paste(nil)
            return true
        }
        return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
    }

    @discardableResult
    private func selectAllFocusedText() -> Bool {
        guard app.isEditingText || focusedTextView() != nil else { return false }
        if let textView = focusedTextView() {
            textView.selectAll(nil)
            return true
        }
        return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
    }

    private func selectAllFilesInActivePane() {
        if app.dualPaneEnabled, app.activePaneID == .secondary {
            var pane = app.secondaryPane
            pane.selectedURLs = Set(pane.items.map(\.url))
            app.secondaryPane = pane
        } else {
            var pane = app.primaryPane
            pane.selectedURLs = Set(pane.items.map(\.url))
            app.primaryPane = pane
        }
    }

    private func focusedTextView() -> NSTextView? {
        NSApp.keyWindow?.firstResponder as? NSTextView
    }

    private func copySelection(cut: Bool) {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        app.copyToClipboard(urls, cut: cut)
    }

    private func navigateActivePane(to url: URL) async {
        if app.dualPaneEnabled, app.activePaneID == .secondary {
            var pane = app.secondaryPane
            await PaneController.navigate(
                &pane,
                to: url,
                using: app.filesystem,
                keepFoldersOnTop: settings.keepFoldersOnTop(directory: url, sortKey: pane.sortKey)
            )
            app.secondaryPane = pane
        } else {
            await navigatePrimary(to: url)
        }
    }

    private func copySelectionPaths() {
        let urls = selectedURLs()
        guard !urls.isEmpty else {
            app.fileOperations.copyPathToPasteboard([app.activePane.currentURL])
            return
        }
        app.fileOperations.copyPathToPasteboard(urls)
    }

    private func pasteClipboard(to destination: URL? = nil) async {
        guard let clip = app.fileClipboard, !clip.urls.isEmpty else { return }
        let destination = destination ?? app.activePane.currentURL
        do {
            if clip.isCut {
                try app.fileOperations.move(items: clip.urls, to: destination, overwrite: false)
                app.clearClipboard()
            } else {
                try app.fileOperations.copy(items: clip.urls, to: destination, overwrite: false)
            }
            await refreshPrimary()
            if app.dualPaneEnabled { await refreshSecondary() }
        } catch let error as FilesystemError {
            if case .nameCollision(let name) = error {
                pendingCollision = PendingCollision(items: clip.urls, destination: destination, move: clip.isCut)
                collisionAlert = L10n.tr("alert.collision.message %@", name)
            } else {
                app.lastErrorMessage = error.localizedDescription
            }
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    private func duplicateSelection() async {
        for url in selectedURLs() {
            do {
                _ = try app.fileOperations.duplicate(url)
            } catch {
                app.lastErrorMessage = error.localizedDescription
                break
            }
        }
        await refreshPrimary()
        if app.dualPaneEnabled { await refreshSecondary() }
    }

    private func showGetInfo() {
        let url = selectedURLs().first ?? app.activePane.currentURL
        do {
            app.infoSummary = try app.fileOperations.makeInfo(for: url)
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    private func openItem(_ item: FileItem, primary: Bool) async {
        if item.isDirectory {
            await openDirectory(item.url, primary: primary)
        } else {
            app.fileOperations.open(item.url)
        }
    }

    private func beginRename(_ item: FileItem) {
        renameTarget = item
        renameText = item.name
        app.isEditingText = true
    }

    private func cancelRename() {
        renameTarget = nil
        renameText = ""
        app.isEditingText = false
    }

    private func performRename() async {
        guard let target = renameTarget else { return }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if newName.isEmpty || newName == target.name {
            cancelRename()
            return
        }
        if settings.warnBeforeChangingExtension,
           !target.isDirectory,
           FileItem.pathExtension(of: target.name) != FileItem.pathExtension(of: newName) {
            pendingRenameName = newName
            showExtensionChangeConfirm = true
            return
        }
        await commitRename(to: newName)
    }

    private func commitRename(to newName: String) async {
        guard let target = renameTarget else { return }
        pendingRenameName = nil
        do {
            _ = try app.fileOperations.rename(item: target.url, to: newName)
            cancelRename()
            await refreshPrimary()
            if app.dualPaneEnabled { await refreshSecondary() }
        } catch {
            app.lastErrorMessage = error.localizedDescription
            let item = target
            let draft = newName
            cancelRename()
            renameText = draft
            renameTarget = item
            app.isEditingText = true
        }
    }

    private func requestTrash() {
        guard !app.activePane.selectedURLs.isEmpty else { return }
        if settings.warnBeforeRemovingFromiCloud,
           app.activePane.selectedURLs.contains(where: { FileItem.isLikelyiCloudURL($0) }) {
            showiCloudTrashConfirm = true
        } else {
            showTrashConfirm = true
        }
    }

    private func performTrash() async {
        let urls = Array(app.activePane.selectedURLs)
        guard !urls.isEmpty else { return }
        do {
            try app.fileOperations.moveToTrash(urls)
            await refreshPrimary()
            if app.dualPaneEnabled { await refreshSecondary() }
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    private func requestEmptyTrash() {
        if settings.warnBeforeEmptyingTrash {
            showEmptyTrashConfirm = true
        } else {
            Task { await performEmptyTrash() }
        }
    }

    private func performEmptyTrash() async {
        do {
            try app.fileOperations.emptyTrash()
            await refreshPrimary()
            if app.dualPaneEnabled { await refreshSecondary() }
        } catch {
            app.lastErrorMessage = error.localizedDescription
        }
    }

    private func runSearch() async {
        let query = app.selectedTab.searchQuery
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            var tab = app.selectedTab
            tab.searchResults = []
            tab.isSearching = false
            app.selectedTab = tab
            return
        }

        let paneID = app.dualPaneEnabled ? app.activePaneID : .primary
        let directory = app.activePane.currentURL

        var tab = app.selectedTab
        tab.isSearching = true
        tab.searchPaneID = paneID
        app.selectedTab = tab

        do {
            let results: [FileItem]
            switch settings.searchScope {
            case .currentFolder:
                results = try app.searchService.search(query: query, in: directory)
            case .thisMac:
                results = try await Task.detached(priority: .userInitiated) {
                    try DirectorySearchService().searchThisMac(query: query)
                }.value
            }
            tab = app.selectedTab
            guard tab.searchQuery == query else { return }
            tab.searchResults = results
            tab.searchPaneID = paneID
            tab.isSearching = false
            app.selectedTab = tab
        } catch {
            tab = app.selectedTab
            guard tab.searchQuery == query else { return }
            app.lastErrorMessage = error.localizedDescription
            tab.searchResults = []
            tab.searchPaneID = paneID
            tab.isSearching = false
            app.selectedTab = tab
        }
    }

    private func transferBetweenPanes(move: Bool) async {
        // Source = selection in the last-activated pane; destination = the other pane.
        let sourceURLs = Array(app.activePane.selectedURLs)
        guard !sourceURLs.isEmpty else { return }
        let destination = app.inactivePane.currentURL
        await runTransfer(items: sourceURLs, to: destination, move: move)
    }

    private func runTransfer(items: [URL], to destination: URL, move: Bool) async {
        app.transferProgress = TransferProgress(completed: 0, total: items.count)
        do {
            if move {
                try await app.fileOperations.moveWithProgress(
                    items: items,
                    to: destination,
                    overwrite: false,
                    progress: { app.transferProgress = $0 },
                    isCancelled: { app.transferProgress?.isCancelled == true }
                )
            } else {
                try await app.fileOperations.copyWithProgress(
                    items: items,
                    to: destination,
                    overwrite: false,
                    progress: { app.transferProgress = $0 },
                    isCancelled: { app.transferProgress?.isCancelled == true }
                )
            }
            app.transferProgress = nil
            await refreshPrimary()
            await refreshSecondary()
        } catch let error as FilesystemError {
            if case .nameCollision(let name) = error {
                pendingCollision = PendingCollision(items: items, destination: destination, move: move)
                collisionAlert = L10n.tr("alert.collision.message %@", name)
            } else if case .cancelled = error {
                app.transferProgress = nil
            } else {
                app.lastErrorMessage = error.localizedDescription
                app.transferProgress = nil
            }
        } catch {
            app.lastErrorMessage = error.localizedDescription
            app.transferProgress = nil
        }
    }

    private func resolveCollision(overwrite: Bool) async {
        guard let pending = pendingCollision else { return }
        collisionAlert = nil
        pendingCollision = nil
        app.transferProgress = TransferProgress(completed: 0, total: pending.items.count)
        do {
            if pending.move {
                try await app.fileOperations.moveWithProgress(
                    items: pending.items,
                    to: pending.destination,
                    overwrite: overwrite,
                    progress: { app.transferProgress = $0 },
                    isCancelled: { app.transferProgress?.isCancelled == true }
                )
            } else {
                try await app.fileOperations.copyWithProgress(
                    items: pending.items,
                    to: pending.destination,
                    overwrite: overwrite,
                    progress: { app.transferProgress = $0 },
                    isCancelled: { app.transferProgress?.isCancelled == true }
                )
            }
            app.transferProgress = nil
            await refreshPrimary()
            await refreshSecondary()
        } catch {
            app.lastErrorMessage = error.localizedDescription
            app.transferProgress = nil
        }
    }
}

private struct PendingCollision {
    let items: [URL]
    let destination: URL
    let move: Bool
}

private struct InfoSheetItem: Identifiable {
    var id: String { summary.path }
    let summary: FileInfoSummary
}

private struct TabChip: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(title, action: onSelect)
                .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("command.close_tab"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct TransferProgressBanner: View {
    let progress: TransferProgress
    let onCancel: () -> Void

    var body: some View {
        HStack {
            ProgressView(value: progress.fraction)
            Text("\(progress.completed)/\(progress.total)")
            Button(L10n.tr("alert.cancel"), action: onCancel)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ExplorerCommandReceiver: ViewModifier {
    let onCommand: (Notification.Name, Any?) -> Void

    private static let commandsPublisher: AnyPublisher<Notification, Never> = {
        let names: [Notification.Name] = [
            .explorerNewTab, .explorerGoBack, .explorerGoForward, .explorerGoUp,
            .explorerRefresh, .explorerOpenFolder, .explorerPathInvalid,
            .explorerNewFolder, .explorerNewFile, .explorerCopy, .explorerCut,
            .explorerPaste, .explorerSelectAll, .explorerDuplicate, .explorerCopyPath, .explorerGetInfo,
            .explorerTrash, .explorerToggleHidden, .explorerToggleDualPane,
            .explorerInstallPlugin, .explorerReloadPlugins, .explorerRevealPlugins,
            .explorerPluginInstallFailed,
            .explorerCompress, .explorerMakeAlias, .explorerQuickLook,
            .explorerOpenInNewPane, .explorerTerminalTab, .explorerTerminalWindow,
            .explorerCustomizeInFinder, .explorerFolderActionsSetup, .explorerShowViewOptions
        ]
        return Publishers.MergeMany(names.map { NotificationCenter.default.publisher(for: $0) })
            .eraseToAnyPublisher()
    }()

    func body(content: Content) -> some View {
        content.onReceive(Self.commandsPublisher) { note in
            onCommand(note.name, note.object)
        }
    }
}

private struct ExplorerDialogs: ViewModifier {
    @Binding var showTrashConfirm: Bool
    @Binding var showiCloudTrashConfirm: Bool
    @Binding var showEmptyTrashConfirm: Bool
    @Binding var showExtensionChangeConfirm: Bool
    @Binding var collisionAlert: String?
    @Binding var pendingCollision: PendingCollision?
    @Binding var lastErrorMessage: String?
    let onTrash: () -> Void
    let onEmptyTrash: () -> Void
    let onConfirmExtensionChange: () -> Void
    let onOverwrite: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(L10n.tr("alert.trash.title"), isPresented: $showTrashConfirm) {
                Button(L10n.tr("alert.cancel"), role: .cancel) {}
                Button(L10n.tr("alert.trash.confirm"), role: .destructive, action: onTrash)
            } message: {
                Text(L10n.tr("alert.trash.message"))
            }
            .alert(L10n.tr("alert.icloud_trash.title"), isPresented: $showiCloudTrashConfirm) {
                Button(L10n.tr("alert.cancel"), role: .cancel) {}
                Button(L10n.tr("alert.trash.confirm"), role: .destructive, action: onTrash)
            } message: {
                Text(L10n.tr("alert.icloud_trash.message"))
            }
            .alert(L10n.tr("alert.empty_trash.title"), isPresented: $showEmptyTrashConfirm) {
                Button(L10n.tr("alert.cancel"), role: .cancel) {}
                Button(L10n.tr("alert.empty_trash.confirm"), role: .destructive, action: onEmptyTrash)
            } message: {
                Text(L10n.tr("alert.empty_trash.message"))
            }
            .alert(L10n.tr("alert.extension.title"), isPresented: $showExtensionChangeConfirm) {
                Button(L10n.tr("alert.cancel"), role: .cancel) {}
                Button(L10n.tr("alert.extension.confirm"), role: .destructive, action: onConfirmExtensionChange)
            } message: {
                Text(L10n.tr("alert.extension.message"))
            }
            .alert(L10n.tr("alert.error.title"), isPresented: Binding(
                get: { lastErrorMessage != nil },
                set: { if !$0 { lastErrorMessage = nil } }
            )) {
                Button(L10n.tr("alert.ok"), role: .cancel) { lastErrorMessage = nil }
            } message: {
                Text(lastErrorMessage ?? "")
            }
            .alert(L10n.tr("alert.collision.title"), isPresented: Binding(
                get: { collisionAlert != nil },
                set: { if !$0 { collisionAlert = nil; pendingCollision = nil } }
            )) {
                Button(L10n.tr("alert.cancel"), role: .cancel) {
                    collisionAlert = nil
                    pendingCollision = nil
                }
                Button(L10n.tr("alert.collision.overwrite"), role: .destructive, action: onOverwrite)
            } message: {
                Text(collisionAlert ?? "")
            }
    }
}
