import AppKit
import SwiftUI

/// Finder-like “Assign Tags to …” popover (search field, color tags, Show All).
struct FinderTagsAssignPopover: View {
    let urls: [URL]
    let title: String
    let onChanged: () -> Void

    @State private var filter = ""
    @State private var showAll = false
    @State private var applied: Set<String> = []
    @State private var catalog: [TagEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            TextField(L10n.tr("tags.filter_placeholder"), text: $filter)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .onSubmit(addTypedTag)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredEntries) { entry in
                        Button {
                            toggle(entry.name)
                        } label: {
                            HStack(spacing: 10) {
                                if let tag = FinderColorTag.matching(entry.name) {
                                    Image(nsImage: tag.swatchImage(size: 12, checked: false))
                                        .resizable()
                                        .frame(width: 12, height: 12)
                                } else {
                                    Circle()
                                        .fill(entry.color)
                                        .frame(width: 12, height: 12)
                                }
                                Text(entry.displayName)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                if applied.contains(where: { $0.caseInsensitiveCompare(entry.name) == .orderedSame }) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 260)

            Divider()

            Button {
                if showAll {
                    showAll = false
                } else {
                    showAll = true
                    reloadCatalog()
                }
            } label: {
                Text(showAll ? L10n.tr("tags.show_less") : L10n.tr("tags.show_all"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 260)
        .onAppear {
            reloadApplied()
            reloadCatalog()
        }
    }

    private var filteredEntries: [TagEntry] {
        let q = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return catalog }
        return catalog.filter {
            $0.displayName.localizedCaseInsensitiveContains(q)
                || $0.name.localizedCaseInsensitiveContains(q)
        }
    }

    private func reloadApplied() {
        var names = Set<String>()
        for url in urls {
            for tag in FinderTags.read(from: url) {
                names.insert(tag)
            }
        }
        applied = names
    }

    private func reloadCatalog() {
        var entries: [TagEntry] = FinderColorTag.allCases.map {
            TagEntry(name: $0.rawValue, displayName: $0.displayName, color: $0.color)
        }

        var seen = Set(entries.map { $0.name.lowercased() })

        func appendUnique(_ name: String) {
            let key = name.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            if let color = FinderColorTag.matching(name) {
                entries.append(TagEntry(name: color.rawValue, displayName: color.displayName, color: color.color))
            } else {
                entries.append(TagEntry(name: name, displayName: name, color: Color.secondary.opacity(0.55)))
            }
        }

        for name in applied { appendUnique(name) }

        if showAll {
            for name in FinderTags.favoriteTagNames() { appendUnique(name) }
        }

        catalog = entries
    }

    private func toggle(_ name: String) {
        do {
            try FinderTags.toggle(named: name, on: urls)
            reloadApplied()
            onChanged()
        } catch {
            // Surface via app on next refresh; keep popover usable.
        }
    }

    private func addTypedTag() {
        let name = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try FinderTags.add(named: name, to: urls)
            filter = ""
            reloadApplied()
            reloadCatalog()
            onChanged()
        } catch {
            // ignore — listing refresh will surface issues if needed
        }
    }
}

private struct TagEntry: Identifiable {
    var id: String { name.lowercased() }
    let name: String
    let displayName: String
    let color: Color
}

/// Compact actions menu (no disclosure chevron) for the toolbar ••• button.
struct ToolbarMoreActionsPopover: View {
    let hasSelection: Bool
    let compressTitle: String
    let onNewFolder: () -> Void
    let onGetInfo: () -> Void
    let onDuplicate: () -> Void
    let onCompress: () -> Void
    let onMakeAlias: () -> Void
    let onQuickLook: () -> Void
    let onCopy: () -> Void
    let onCopyPath: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            action(L10n.tr("action.new_folder"), enabled: true, onNewFolder)
            action(L10n.tr("action.get_info"), enabled: hasSelection, onGetInfo)
            Divider().padding(.vertical, 4)
            action(L10n.tr("action.duplicate"), enabled: hasSelection, onDuplicate)
            action(compressTitle, enabled: hasSelection, onCompress)
            action(L10n.tr("action.make_alias"), enabled: hasSelection, onMakeAlias)
            action(L10n.tr("action.quick_look"), enabled: hasSelection, onQuickLook)
            Divider().padding(.vertical, 4)
            action(L10n.tr("action.copy"), enabled: hasSelection, onCopy)
            action(L10n.tr("action.copy_path"), enabled: hasSelection, onCopyPath)
            Divider().padding(.vertical, 4)
            action(L10n.tr("action.menu_settings"), enabled: true, onSettings)
        }
        .padding(.vertical, 6)
        .frame(minWidth: 200)
    }

    private func action(_ title: String, enabled: Bool, _ handler: @escaping () -> Void) -> some View {
        Button(action: handler) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? .primary : .tertiary)
    }
}
