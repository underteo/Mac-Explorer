import SwiftUI
import AppKit

/// Finder-like file list backed by AppKit `NSTableView` for instant selection highlighting.
struct NativeFileTableView: NSViewRepresentable {
    let items: [FileItem]
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
        scroll.drawsBackground = false

        let table = RightClickSelectsTableView()
        table.style = .plain
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.allowsColumnSelection = false
        table.allowsColumnReordering = true
        table.usesAlternatingRowBackgroundColors = true
        table.rowSizeStyle = .small
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.doubleClick(_:))
        table.headerView = NSTableHeaderView()

        for column in Coordinator.makeColumns() {
            table.addTableColumn(column)
        }

        scroll.documentView = table
        context.coordinator.tableView = table
        context.coordinator.parent = self
        context.coordinator.installMenuIfNeeded()
        context.coordinator.reload(items: items, selection: selection, renameURL: renameURL)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.reload(items: items, selection: selection, renameURL: renameURL)
    }

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate, NSMenuDelegate {
        enum ColumnID: String {
            case name, date, size, kind
        }

        var parent: NativeFileTableView
        weak var tableView: NSTableView?
        private var items: [FileItem] = []
        private var isUpdatingSelection = false
        private var renameField: NSTextField?
        private var renameRow: Int?
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
            let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(ColumnID.name.rawValue))
            name.title = L10n.tr("column.name")
            name.minWidth = 180
            name.width = 280
            name.resizingMask = [.autoresizingMask, .userResizingMask]

            let date = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(ColumnID.date.rawValue))
            date.title = L10n.tr("column.date")
            date.minWidth = 120
            date.width = 160

            let size = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(ColumnID.size.rawValue))
            size.title = L10n.tr("column.size")
            size.minWidth = 70
            size.width = 90

            let kind = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(ColumnID.kind.rawValue))
            kind.title = L10n.tr("column.kind")
            kind.minWidth = 80
            kind.width = 120

            return [name, date, size, kind]
        }

        func reload(items: [FileItem], selection: Set<URL>, renameURL: URL?) {
            let itemsChanged = itemsDiffer(from: items)
            self.items = items

            guard let table = tableView else { return }

            if itemsChanged {
                table.reloadData()
            }

            syncSelection(selection)
            syncRename(renameURL: renameURL)
        }

        /// Avoid allocating mapped arrays on every SwiftUI `updateNSView`.
        private func itemsDiffer(from newItems: [FileItem]) -> Bool {
            guard items.count == newItems.count else { return true }
            for index in items.indices {
                if items[index].url != newItems[index].url || items[index].name != newItems[index].name {
                    return true
                }
            }
            return false
        }

        private func syncSelection(_ selection: Set<URL>) {
            guard let table = tableView else { return }
            isUpdatingSelection = true
            defer { isUpdatingSelection = false }

            let indexes = IndexSet(items.enumerated().compactMap { offset, item in
                selection.contains(item.url) ? offset : nil
            })
            if table.selectedRowIndexes != indexes {
                table.selectRowIndexes(indexes, byExtendingSelection: false)
            }
        }

        private func syncRename(renameURL: URL?) {
            guard let table = tableView else { return }
            if let renameURL,
               let row = items.firstIndex(where: { $0.url == renameURL }) {
                if renameRow != row || renameField == nil {
                    beginInlineRename(row: row, item: items[row])
                }
            } else if renameField != nil {
                let row = renameRow
                endInlineRename(commit: false, notify: false)
                if let row, row >= 0, row < items.count {
                    table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
                }
            }
        }

        func installMenuIfNeeded() {
            guard let table = tableView else { return }
            if table.menu?.delegate === self { return }
            let menu = NSMenu()
            menu.delegate = self
            table.menu = menu
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            // Ensure the row under the cursor is selected before building the menu (Finder-like).
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
            guard let table = tableView as? RightClickSelectsTableView else { return }
            table.applyPendingRightClickSelection()
        }

        @objc func doubleClick(_ sender: Any?) {
            guard let table = tableView, table.clickedRow >= 0, table.clickedRow < items.count else { return }
            parent.onOpen(items[table.clickedRow])
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            items.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0, row < items.count, let tableColumn else { return nil }
            let item = items[row]
            let id = tableColumn.identifier.rawValue

            if id == ColumnID.name.rawValue {
                if renameURLMatches(item), let field = renameField, renameRow == row {
                    return field
                }
                return nameCell(for: item, tableView: tableView)
            }

            let cell = textCell(tableView: tableView, identifier: id)
            cell.textField?.textColor = .secondaryLabelColor
            switch id {
            case ColumnID.date.rawValue:
                cell.textField?.stringValue = item.contentModificationDate.map { dateFormatter.string(from: $0) } ?? "—"
            case ColumnID.size.rawValue:
                if let size = item.fileSize, !item.isDirectory {
                    cell.textField?.stringValue = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                } else {
                    cell.textField?.stringValue = "—"
                }
            case ColumnID.kind.rawValue:
                cell.textField?.stringValue = item.kindLabel
            default:
                cell.textField?.stringValue = ""
            }
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isUpdatingSelection, let table = tableView else { return }
            let urls = Set(table.selectedRowIndexes.compactMap { index -> URL? in
                guard index >= 0, index < items.count else { return nil }
                return items[index].url
            })
            // Highlight is already painted by AppKit. Sync SwiftUI state on the next
            // turn so we never stall the selection draw on ObservableObject updates.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent.selection != urls else { return }
                self.parent.selection = urls
            }
        }

        private func selectedURLs() -> Set<URL> {
            guard let table = tableView else { return [] }
            return Set(table.selectedRowIndexes.compactMap { index -> URL? in
                guard index >= 0, index < items.count else { return nil }
                return items[index].url
            })
        }

        private func renameURLMatches(_ item: FileItem) -> Bool {
            parent.renameURL == item.url
        }

        private func nameCell(for item: FileItem, tableView: NSTableView) -> NSTableCellView {
            let identifier = NSUserInterfaceItemIdentifier("NameCell")
            let cell = (tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView) ?? {
                let cell = NSTableCellView()
                cell.identifier = identifier

                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.imageScaling = .scaleProportionallyDown

                let text = NSTextField(labelWithString: "")
                text.translatesAutoresizingMaskIntoConstraints = false
                text.lineBreakMode = .byTruncatingTail
                text.isEditable = false
                text.isBordered = false
                text.drawsBackground = false

                cell.addSubview(imageView)
                cell.addSubview(text)
                cell.imageView = imageView
                cell.textField = text

                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    text.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
                return cell
            }()

            cell.imageView?.image = FileIconCache.icon(for: item.url, size: 16)
            cell.textField?.stringValue = item.listedName(showExtension: parent.showFilenameExtensions)
            cell.textField?.isHidden = false
            return cell
        }

        private func textCell(tableView: NSTableView, identifier: String) -> NSTableCellView {
            let id = NSUserInterfaceItemIdentifier(identifier)
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView) ?? {
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

        private func beginInlineRename(row: Int, item: FileItem) {
            guard let table = tableView else { return }
            endInlineRename(commit: false, notify: false)

            let field = NSTextField(string: parent.renameText.isEmpty ? item.name : parent.renameText)
            field.isBordered = true
            field.isBezeled = true
            field.bezelStyle = .roundedBezel
            field.delegate = self
            field.target = self
            field.action = #selector(submitRename(_:))
            field.cell?.sendsActionOnEndEditing = false

            renameField = field
            renameRow = row
            renameFinished = false
            parent.renameText = field.stringValue

            table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))

            DispatchQueue.main.async {
                table.window?.makeFirstResponder(field)
                let range = RenameSelection.selectedRange(for: field.stringValue, isDirectory: item.isDirectory)
                field.currentEditor()?.selectedRange = range
            }
        }

        private func endInlineRename(commit: Bool, notify: Bool) {
            guard renameField != nil else { return }
            let field = renameField
            renameField = nil
            let row = renameRow
            renameRow = nil
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
            if let table = tableView, let row, row >= 0, row < items.count {
                table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
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

/// Selects the clicked row on right-click (unless it is already part of the selection).
private final class RightClickSelectsTableView: NSTableView {
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
            // Finder: unselected row → select only that row; already selected → keep multi-selection.
            if !selectedRowIndexes.contains(row) {
                selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        } else {
            // Empty area: clear selection so the background menu applies.
            deselectAll(nil)
        }
    }
}
