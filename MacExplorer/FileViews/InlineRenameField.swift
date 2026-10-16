import SwiftUI
import AppKit

enum RenameSelection {
    /// Range of the basename (before the last `.extension`), or the whole name for folders / extensionless files.
    static func selectedRange(for name: String, isDirectory: Bool) -> NSRange {
        let ns = name as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard !isDirectory, ns.length > 0 else { return full }
        let ext = ns.pathExtension
        guard !ext.isEmpty, ns.length > ext.count + 1 else { return full }
        let basenameLength = ns.length - ext.count - 1
        guard basenameLength > 0 else { return full }
        return NSRange(location: 0, length: basenameLength)
    }
}

/// Inline name editor that selects the basename (before `.ext`) like Finder/Explorer.
struct InlineRenameField: NSViewRepresentable {
    @Binding var text: String
    var isDirectory: Bool
    var onCommit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.focusRingType = .default
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.cell?.sendsActionOnEndEditing = false

        DispatchQueue.main.async {
            context.coordinator.activate(field)
            // Second pass after the field is in the window hierarchy.
            DispatchQueue.main.async {
                context.coordinator.activate(field)
            }
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InlineRenameField
        private var didFinish = false

        init(parent: InlineRenameField) {
            self.parent = parent
        }

        func activate(_ field: NSTextField) {
            didFinish = false
            field.stringValue = parent.text
            field.window?.makeFirstResponder(field)
            let range = RenameSelection.selectedRange(for: field.stringValue, isDirectory: parent.isDirectory)
            field.currentEditor()?.selectedRange = range
        }

        @objc func submit(_ sender: NSTextField) {
            finish(commit: true, field: sender)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            // Escape sets reason to cancelled text movement via doCommandBy.
            finish(commit: true, field: field)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let field = control as? NSTextField {
                    finish(commit: false, field: field)
                }
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let field = control as? NSTextField {
                    finish(commit: true, field: field)
                }
                return true
            }
            return false
        }

        private func finish(commit: Bool, field: NSTextField) {
            guard !didFinish else { return }
            didFinish = true
            parent.text = field.stringValue
            field.window?.makeFirstResponder(nil)
            if commit {
                parent.onCommit()
            } else {
                parent.onCancel()
            }
        }
    }
}
