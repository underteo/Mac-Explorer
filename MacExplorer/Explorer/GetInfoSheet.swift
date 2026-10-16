import SwiftUI
import AppKit

struct GetInfoSheet: View {
    let info: FileInfoSummary
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("info.title"))
                .font(.title2.weight(.semibold))

            LabeledContent(L10n.tr("info.name"), value: info.name)
            LabeledContent(L10n.tr("info.kind"), value: info.kind)
            LabeledContent(L10n.tr("info.size"), value: info.sizeLabel)
            LabeledContent(L10n.tr("info.created"), value: info.createdLabel)
            LabeledContent(L10n.tr("info.modified"), value: info.modifiedLabel)
            LabeledContent(L10n.tr("info.permissions"), value: info.permissionsLabel)
            if info.isSymbolicLink {
                Text(L10n.tr("info.symlink"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Text(info.path)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.secondary)

            HStack {
                Button(L10n.tr("action.reveal_finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([info.url])
                }
                Spacer()
                Button(L10n.tr("alert.ok"), action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}
