import SwiftUI

/// Always-editable path field: no pencil, no Go button, no focus halo.
struct PathLocationBar: View {
    let url: URL
    let onNavigate: (URL) -> Void
    var onEditingChanged: ((Bool) -> Void)?

    @State private var draftPath = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        TextField(L10n.tr("path.placeholder"), text: $draftPath)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .focused($fieldFocused)
            .focusEffectDisabled()
            .onSubmit(commitPath)
            .onExitCommand(perform: cancelEditing)
            .accessibilityLabel(L10n.tr("path.edit"))
            .accessibilityValue(draftPath)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { draftPath = url.path }
            .onChange(of: url) { _, newURL in
                if !fieldFocused {
                    draftPath = newURL.path
                }
            }
            .onChange(of: fieldFocused) { _, focused in
                onEditingChanged?(focused)
                if !focused {
                    draftPath = url.path
                }
            }
    }

    private func cancelEditing() {
        draftPath = url.path
        fieldFocused = false
    }

    private func commitPath() {
        let trimmed = draftPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded: String
        if trimmed.hasPrefix("~") {
            expanded = (trimmed as NSString).expandingTildeInPath
        } else {
            expanded = trimmed
        }
        let candidate = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            NotificationCenter.default.post(
                name: .explorerPathInvalid,
                object: L10n.tr("path.invalid")
            )
            fieldFocused = true
            return
        }
        fieldFocused = false
        onNavigate(candidate)
    }
}
