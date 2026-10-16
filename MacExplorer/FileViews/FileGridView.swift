import SwiftUI
import AppKit

struct FileGridView<ItemMenu: View, BackgroundMenu: View>: View {
    let items: [FileItem]
    @Binding var selection: Set<URL>
    let onOpen: (FileItem) -> Void
    var renameURL: URL?
    @Binding var renameText: String
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    @ViewBuilder let itemMenu: (FileItem) -> ItemMenu
    @ViewBuilder let backgroundMenu: () -> BackgroundMenu

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: max(geo.size.height, 1))
                        .contentShape(Rectangle())
                        .contextMenu { backgroundMenu() }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { item in
                            FileGridCell(
                                item: item,
                                isSelected: selection.contains(item.url),
                                isRenaming: renameURL == item.url,
                                renameText: $renameText,
                                onCommitRename: onCommitRename,
                                onCancelRename: onCancelRename,
                                onOpen: { onOpen(item) },
                                onSelect: { exclusive in
                                    if exclusive {
                                        selection = [item.url]
                                    } else if selection.contains(item.url) {
                                        selection.remove(item.url)
                                    } else {
                                        selection.insert(item.url)
                                    }
                                }
                            )
                            .contextMenu {
                                // Right-click acts like a left-click first: select the item if needed.
                                Color.clear
                                    .frame(width: 0, height: 0)
                                    .onAppear {
                                        if !selection.contains(item.url) {
                                            selection = [item.url]
                                        }
                                    }
                                itemMenu(item)
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
            }
        }
    }
}

private struct FileGridCell: View {
    let item: FileItem
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameText: String
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    var onOpen: () -> Void
    var onSelect: (_ exclusive: Bool) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: FileIconCache.icon(for: item.url, size: 48))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            if isRenaming {
                InlineRenameField(
                    text: $renameText,
                    isDirectory: item.isDirectory,
                    onCommit: onCommitRename,
                    onCancel: onCancelRename
                )
                .frame(maxWidth: 140, minHeight: 22)
            } else {
                Text(item.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard !isRenaming else { return }
            onOpen()
        }
        .onTapGesture {
            guard !isRenaming else { return }
            onSelect(!NSEvent.modifierFlags.contains(.command))
        }
        .accessibilityLabel(item.name)
    }
}
