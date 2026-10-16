import SwiftUI
import AppKit

/// Finder-like file list as an outline: rows with disclosure triangles to expand folders in place.
struct NativeFileTableView: NSViewRepresentable {
    let items: [FileItem]
    let sortKey: FileSortKey
    let sortAscending: Bool
    let keepFoldersOnTop: Bool
    let includeHiddenFiles: Bool
    @Binding var selection: Set<URL>
    var renameURL: URL?
    @Binding var renameText: String
    var showFilenameExtensions: Bool = true
    var onOpen: (FileItem) -> Void
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    var makeContextMenu: (Set<URL>) -> NSMenu

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .controlBackgroundColor

        let outline = RightClickSelectsOutlineView()
        outline.style = .plain
        outline.allowsMultipleSelection = true
        outline.allowsEmptySelection = true
        outline.allowsColumnSelection = false
        outline.allowsColumnReordering = true
        outline.usesAlternatingRowBackgroundColors = true
        outline.backgroundColor = .controlBackgroundColor
        outline.rowSizeStyle = .small
        outline.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outline.indentationPerLevel = 16
        outline.indentationMarkerFollowsCell = true
        outline.autosaveExpandedItems = false
        outline.delegate = context.coordinator
        outline.dataSource = context.coordinator
        outline.target = context.coordinator
        outline.doubleAction = #selector(Coordinator.doubleClick(_:))
        outline.headerView = ReadableTableHeaderView(frame: NSRect(x: 0, y: 0, width: 0, height: 24))

        for column in Coordinator.makeColumns() {
            outline.addTableColumn(column)
        }
        if let name = outline.tableColumns.first {
            outline.outlineTableColumn = name
        }

        scroll.documentView = outline
        context.coordinator.outlineView = outline
        context.coordinator.parent = self
        context.coordinator.installMenuIfNeeded()
        context.coordinator.reload(items: items, selection: selection, renameURL: renameURL)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.reload(items: items, selection: selection, renameURL: renameURL)
    }

    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextFieldDelegate, NSMenuDelegate {
        enum ColumnID: String {
            case name, date, size, kind
        }

        var parent: NativeFileTableView
        weak var outlineView: NSOutlineView?
        private var rootNodes: [FileOutlineNode] = []
        private var expandedURLs: Set<URL> = []
        private var isUpdatingSelection = false
        private var renameField: NSTextField?
        private var renameURLActive: URL?
        private var renameFinished = false

        private let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()

        init(parent: NativeFileTableView) {
            self.parent = parent
        }

        static func makeColumns() -> [NSTableColumn] {
            func column(_ id: ColumnID, titleKey: String, minWidth: CGFloat, width: CGFloat) -> NSTableColumn {
                let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id.rawValue))
                let title = L10n.tr(titleKey)
                col.title = title
                col.headerCell.title = title
                col.headerCell.textColor = .secondaryLabelColor
                col.minWidth = minWidth
                col.width = width
                return col
            }

            let name = column(.name, titleKey: "column.name", minWidth: 180, width: 280)
            name.resizingMask = [.autoresizingMask, .userResizingMask]

            return [
                name,
                column(.date, titleKey: "column.date", minWidth: 120, width: 160),
                column(.size, titleKey: "column.size", minWidth: 70, width: 90),
                column(.kind, titleKey: "column.kind", minWidth: 80, width: 120)
            ]
        }

        func reload(items: [FileItem], selection: Set<URL>, renameURL: URL?) {
            let previousExpanded = expandedURLs
            let itemsChanged = rootItemsDiffer(from: items)
            if itemsChanged {
                rootNodes = items.map { FileOutlineNode(item: $0) }
                outlineView?.reloadData()
                restoreExpandedState(previousExpanded)
            }

            syncSelection(selection)
            syncRename(renameURL: renameURL)
        }

        private func rootItemsDiffer(from newItems: [FileItem]) -> Bool {
            guard rootNodes.count == newItems.count else { return true }
            for index in rootNodes.indices {
                let old = rootNodes[index].item
                let new = newItems[index]
                if old.url != new.url || old.name != new.name || old.tagNames != new.tagNames {
                    return true
                }
            }
            return false
        }

        private func restoreExpandedState(_ urls: Set<URL>) {
            guard let outline = outlineView, !urls.isEmpty else { return }
            func expand(_ nodes: [FileOutlineNode]) {
                for node in nodes where node.item.isDirectory && urls.contains(node.item.url) {
                    _ = loadChildrenIfNeeded(for: node)
                    outline.expandItem(node, expandChildren: false)
                    if let children = node.children {
                        expand(children)
                    }
                }
            }
            expand(rootNodes)
        }

        private func syncSelection(_ selection: Set<URL>) {
            guard let outline = outlineView else { return }
            isUpdatingSelection = true
            defer { isUpdatingSelection = false }

            var indexes = IndexSet()
            for row in 0..<outline.numberOfRows {
                if let node = outline.item(atRow: row) as? FileOutlineNode,
                   selection.contains(node.item.url) {
                    indexes.insert(row)
                }
            }
            if outline.selectedRowIndexes != indexes {
                outline.selectRowIndexes(indexes, byExtendingSelection: false)
            }
        }

        private func syncRename(renameURL: URL?) {
            guard let outline = outlineView else { return }
            if let renameURL, let node = findNode(url: renameURL) {
                let row = outline.row(forItem: node)
                if renameURLActive != renameURL || renameField == nil, row >= 0 {
                    beginInlineRename(node: node)
                }
            } else if renameField != nil {
                let url = renameURLActive
                endInlineRename(commit: false, notify: false)
                if let url, let node = findNode(url: url) {
                    outline.reloadItem(node)
                }
            }
        }

        private func findNode(url: URL, in nodes: [FileOutlineNode]? = nil) -> FileOutlineNode? {
            let list = nodes ?? rootNodes
            for node in list {
                if node.item.url == url { return node }
                if let found = findNode(url: url, in: node.children ?? []) {
                    return found
                }
            }
            return nil
        }

        func installMenuIfNeeded() {
            guard let outline = outlineView else { return }
            if outline.menu?.delegate === self { return }
            let menu = NSMenu()
            menu.delegate = self
            outline.menu = menu
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            selectRowUnderPendingRightClickIfNeeded()
            menu.removeAllItems()
            let urls = selectedURLs()
            let built = parent.makeContextMenu(urls)
            while !built.items.isEmpty {
                let item = built.items[0]
                built.removeItem(at: 0)
                menu.addItem(item)
            }
        }

        private func selectRowUnderPendingRightClickIfNeeded() {
            guard let outline = outlineView as? RightClickSelectsOutlineView else { return }
            outline.applyPendingRightClickSelection()
        }

        @objc func doubleClick(_ sender: Any?) {
            guard let outline = outlineView, outline.clickedRow >= 0,
                  let node = outline.item(atRow: outline.clickedRow) as? FileOutlineNode else { return }
            parent.onOpen(node.item)
        }

        // MARK: - NSOutlineViewDataSource

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if item == nil { return rootNodes.count }
            guard let node = item as? FileOutlineNode else { return 0 }
            return loadChildrenIfNeeded(for: node).count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if item == nil { return rootNodes[index] }
            let node = item as! FileOutlineNode
            return loadChildrenIfNeeded(for: node)[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            (item as? FileOutlineNode)?.item.isDirectory == true
        }

        @discardableResult
        private func loadChildrenIfNeeded(for node: FileOutlineNode) -> [FileOutlineNode] {
            if let children = node.children { return children }
            var listing = DirectoryListingService(includeHiddenFiles: parent.includeHiddenFiles)
            do {
                let items = try listing.listContents(
                    of: node.item.url,
                    sortKey: parent.sortKey,
                    ascending: parent.sortAscending,
                    keepFoldersOnTop: parent.keepFoldersOnTop
                )
                let children = items.map { FileOutlineNode(item: $0, parent: node) }
                node.children = children
                return children
            } catch {
                node.children = []
                return []
            }
        }

        func outlineViewItemDidExpand(_ notification: Notification) {
            guard let node = notification.userInfo?["NSObject"] as? FileOutlineNode else { return }
            expandedURLs.insert(node.item.url)
            outlineView?.reloadItem(node)
        }

        func outlineViewItemDidCollapse(_ notification: Notification) {
            guard let node = notification.userInfo?["NSObject"] as? FileOutlineNode else { return }
            expandedURLs.remove(node.item.url)
            // Also drop nested expansions under this node.
            func removeDescendants(_ n: FileOutlineNode) {
                for child in n.children ?? [] {
                    expandedURLs.remove(child.item.url)
                    removeDescendants(child)
                }
            }
            removeDescendants(node)
            outlineView?.reloadItem(node)
        }

        // MARK: - NSOutlineViewDelegate

        func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            let id = NSUserInterfaceItemIdentifier("AlternatingRow")
            let rowView = (outlineView.makeView(withIdentifier: id, owner: nil) as? AlternatingTableRowView)
                ?? AlternatingTableRowView()
            rowView.identifier = id
            rowView.rowIndex = outlineView.row(forItem: item)
            return rowView
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? FileOutlineNode, let tableColumn else { return nil }
            let file = node.item
            let id = tableColumn.identifier.rawValue

            if id == ColumnID.name.rawValue {
                if parent.renameURL == file.url, let field = renameField, renameURLActive == file.url {
                    return field
                }
                let isOpen = file.isDirectory && outlineView.isItemExpanded(node)
                return nameCell(for: file, outlineView: outlineView, folderOpen: isOpen)
            }

            let cell = textCell(outlineView: outlineView, identifier: id)
            cell.textField?.textColor = .secondaryLabelColor
            switch id {
            case ColumnID.date.rawValue:
                cell.textField?.stringValue = file.contentModificationDate.map { dateFormatter.string(from: $0) } ?? "—"
            case ColumnID.size.rawValue:
                if let size = file.fileSize, !file.isDirectory {
                    cell.textField?.stringValue = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                } else {
                    cell.textField?.stringValue = "—"
                }
            case ColumnID.kind.rawValue:
                cell.textField?.stringValue = file.kindLabel
            default:
                cell.textField?.stringValue = ""
            }
            return cell
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !isUpdatingSelection, let outline = outlineView else { return }
            let urls = selectedURLs()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent.selection != urls else { return }
                self.parent.selection = urls
            }
        }

        private func selectedURLs() -> Set<URL> {
            guard let outline = outlineView else { return [] }
            return Set(outline.selectedRowIndexes.compactMap { row -> URL? in
                (outline.item(atRow: row) as? FileOutlineNode)?.item.url
            })
        }

        private func nameCell(for item: FileItem, outlineView: NSOutlineView, folderOpen: Bool) -> NSTableCellView {
            let identifier = NSUserInterfaceItemIdentifier("NameCell")
            let cell = (outlineView.makeView(withIdentifier: identifier, owner: nil) as? NameTagCellView) ?? {
                let cell = NameTagCellView()
                cell.identifier = identifier
                return cell
            }()

            cell.configure(
                icon: FileIconCache.icon(for: item, size: 16, folderOpen: folderOpen),
                name: item.listedName(showExtension: parent.showFilenameExtensions),
                tagColors: item.finderColorTags
            )
            return cell
        }

        private func textCell(outlineView: NSOutlineView, identifier: String) -> NSTableCellView {
            let id = NSUserInterfaceItemIdentifier(identifier)
            let cell = (outlineView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView) ?? {
                let cell = NSTableCellView()
                cell.identifier = id
                let text = NSTextField(labelWithString: "")
                text.translatesAutoresizingMaskIntoConstraints = false
                text.isEditable = false
                text.isBordered = false
                text.drawsBackground = false
                text.lineBreakMode = .byTruncatingTail
                cell.addSubview(text)
                cell.textField = text
                NSLayoutConstraint.activate([
                    text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                    text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                    text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
                return cell
            }()
            return cell
        }

        private func beginInlineRename(node: FileOutlineNode) {
            guard let outline = outlineView else { return }
            endInlineRename(commit: false, notify: false)

            let item = node.item
            let field = NSTextField(string: parent.renameText.isEmpty ? item.name : parent.renameText)
            field.isBordered = true
            field.isBezeled = true
            field.bezelStyle = .roundedBezel
            field.delegate = self
            field.target = self
            field.action = #selector(submitRename(_:))
            field.cell?.sendsActionOnEndEditing = false

            renameField = field
            renameURLActive = item.url
            renameFinished = false
            parent.renameText = field.stringValue

            outline.reloadItem(node)

            DispatchQueue.main.async {
                outline.window?.makeFirstResponder(field)
                let range = RenameSelection.selectedRange(for: field.stringValue, isDirectory: item.isDirectory)
                field.currentEditor()?.selectedRange = range
            }
        }

        private func endInlineRename(commit: Bool, notify: Bool) {
            guard renameField != nil else { return }
            let field = renameField
            renameField = nil
            let url = renameURLActive
            renameURLActive = nil
            if let field {
                parent.renameText = field.stringValue
            }
            if notify {
                if commit {
                    parent.onCommitRename()
                } else {
                    parent.onCancelRename()
                }
            }
            if let outline = outlineView, let url, let node = findNode(url: url) {
                outline.reloadItem(node)
            }
            _ = field
        }

        @objc private func submitRename(_ sender: NSTextField) {
            finishRename(commit: true)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            finishRename(commit: true)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                finishRename(commit: false)
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                finishRename(commit: true)
                return true
            }
            return false
        }

        private func finishRename(commit: Bool) {
            guard !renameFinished else { return }
            renameFinished = true
            endInlineRename(commit: commit, notify: true)
        }
    }
}

/// Tree node for the list outline (lazy-loaded children).
@MainActor
private final class FileOutlineNode: NSObject {
    let item: FileItem
    weak var parent: FileOutlineNode?
    var children: [FileOutlineNode]?

    init(item: FileItem, parent: FileOutlineNode? = nil) {
        self.item = item
        self.parent = parent
    }
}

/// Explicit zebra rows — system alternating colors are easy to lose inside a SwiftUI-hosted scroll view.
@MainActor
private final class AlternatingTableRowView: NSTableRowView {
    var rowIndex: Int = 0

    override func drawBackground(in dirtyRect: NSRect) {
        if isSelected {
            super.drawBackground(in: dirtyRect)
            return
        }
        let pair = NSColor.alternatingContentBackgroundColors
        let fill = pair.indices.contains(rowIndex % 2) ? pair[rowIndex % 2] : .controlBackgroundColor
        fill.setFill()
        bounds.fill()
    }
}

/// Table header with readable label contrast (Tahoe glass defaults are near-invisible).
@MainActor
private final class ReadableTableHeaderView: NSTableHeaderView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 26)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        guard let table = tableView else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        var x = CGFloat(0)
        for column in table.tableColumns where !column.isHidden {
            let width = column.width
            let title = column.headerCell.stringValue as NSString
            let size = title.size(withAttributes: attrs)
            let point = NSPoint(
                x: x + 8,
                y: (bounds.height - size.height) / 2
            )
            title.draw(at: point, withAttributes: attrs)
            x += width
        }

        NSColor.separatorColor.withAlphaComponent(0.55).setStroke()
        let bottom = NSBezierPath()
        bottom.move(to: NSPoint(x: bounds.minX, y: bounds.minY + 0.5))
        bottom.line(to: NSPoint(x: bounds.maxX, y: bounds.minY + 0.5))
        bottom.lineWidth = 1
        bottom.stroke()
    }
}

/// Name column cell: icon + label + Finder tag dots (same palette as Finder).
@MainActor
private final class NameTagCellView: NSTableCellView {
    private let dotsView = FinderTagDotsStackView()
    private var textTrailingToDots: NSLayoutConstraint?
    private var textTrailingToEdge: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func configure(icon: NSImage, name: String, tagColors: [FinderColorTag]) {
        imageView?.image = icon
        textField?.stringValue = name
        textField?.isHidden = false
        dotsView.setColors(tagColors)
        dotsView.isHidden = tagColors.isEmpty
        textTrailingToDots?.isActive = !tagColors.isEmpty
        textTrailingToEdge?.isActive = tagColors.isEmpty
    }

    private func setup() {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown

        let text = NSTextField(labelWithString: "")
        text.translatesAutoresizingMaskIntoConstraints = false
        text.lineBreakMode = .byTruncatingTail
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        text.isEditable = false
        text.isBordered = false
        text.drawsBackground = false

        dotsView.translatesAutoresizingMaskIntoConstraints = false
        dotsView.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(imageView)
        addSubview(text)
        addSubview(dotsView)
        self.imageView = imageView
        self.textField = text

        let toDots = text.trailingAnchor.constraint(lessThanOrEqualTo: dotsView.leadingAnchor, constant: -6)
        let toEdge = text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        textTrailingToDots = toDots
        textTrailingToEdge = toEdge

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),
            text.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            toEdge,
            dotsView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            dotsView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotsView.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
}

@MainActor
private final class RightClickSelectsOutlineView: NSOutlineView {
    private var pendingRightClickRow: Int?

    override func rightMouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let row = self.row(at: local)
        pendingRightClickRow = row
        applyPendingRightClickSelection()
        super.rightMouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let local = convert(event.locationInWindow, from: nil)
        pendingRightClickRow = self.row(at: local)
        applyPendingRightClickSelection()
        return super.menu(for: event)
    }

    func applyPendingRightClickSelection() {
        guard let row = pendingRightClickRow else { return }
        pendingRightClickRow = nil
        if row >= 0 {
            if !selectedRowIndexes.contains(row) {
                selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        } else {
            deselectAll(nil)
        }
    }
}
