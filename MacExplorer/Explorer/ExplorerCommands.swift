import SwiftUI

struct ExplorerCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L10n.tr("command.new_window")) {
                openWindow(id: "explorer")
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(L10n.tr("command.new_tab")) {
                NotificationCenter.default.post(name: .explorerNewTab, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command])

            Button(L10n.tr("command.new_pane")) {
                NotificationCenter.default.post(name: .explorerToggleDualPane, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button(L10n.tr("action.new_folder")) {
                NotificationCenter.default.post(name: .explorerNewFolder, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Menu(L10n.tr("action.new_file")) {
                ForEach(FileTemplate.allCases) { template in
                    Button(template.displayName) {
                        NotificationCenter.default.post(name: .explorerNewFile, object: template.rawValue)
                    }
                }
            }
        }

        CommandGroup(after: .newItem) {
            Button(L10n.tr("toolbar.refresh")) {
                NotificationCenter.default.post(name: .explorerRefresh, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])
        }

        // Replace system Edit pasteboard so ⌘C/⌘V drive the file clipboard, not text.
        CommandGroup(replacing: .pasteboard) {
            Button(L10n.tr("action.copy")) {
                NotificationCenter.default.post(name: .explorerCopy, object: nil)
            }
            .keyboardShortcut("c", modifiers: [.command])

            Button(L10n.tr("action.cut")) {
                NotificationCenter.default.post(name: .explorerCut, object: nil)
            }
            .keyboardShortcut("x", modifiers: [.command])

            Button(L10n.tr("action.paste")) {
                NotificationCenter.default.post(name: .explorerPaste, object: nil)
            }
            .keyboardShortcut("v", modifiers: [.command])

            Button(L10n.tr("action.duplicate")) {
                NotificationCenter.default.post(name: .explorerDuplicate, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command])

            Button(L10n.tr("action.copy_path")) {
                NotificationCenter.default.post(name: .explorerCopyPath, object: nil)
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
        }

        CommandMenu(L10n.tr("menu.go")) {
            Button(L10n.tr("command.back")) {
                NotificationCenter.default.post(name: .explorerGoBack, object: nil)
            }
            .keyboardShortcut("[", modifiers: [.command])

            Button(L10n.tr("command.forward")) {
                NotificationCenter.default.post(name: .explorerGoForward, object: nil)
            }
            .keyboardShortcut("]", modifiers: [.command])

            Button(L10n.tr("command.enclosing_folder")) {
                NotificationCenter.default.post(name: .explorerGoUp, object: nil)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command])

            Divider()

            Button(L10n.tr("toolbar.open_folder")) {
                NotificationCenter.default.post(name: .explorerOpenFolder, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandMenu(L10n.tr("menu.view")) {
            Button(L10n.tr("command.toggle_hidden")) {
                NotificationCenter.default.post(name: .explorerToggleHidden, object: nil)
            }
            .keyboardShortcut(".", modifiers: [.command, .shift])

            Button(L10n.tr("toolbar.dual_pane")) {
                NotificationCenter.default.post(name: .explorerToggleDualPane, object: nil)
            }
        }

        CommandMenu(L10n.tr("menu.file_ops")) {
            Button(L10n.tr("action.get_info")) {
                NotificationCenter.default.post(name: .explorerGetInfo, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command])

            Button(L10n.tr("action.move_to_trash")) {
                NotificationCenter.default.post(name: .explorerTrash, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }

        CommandMenu(L10n.tr("menu.plugins")) {
            Button(L10n.tr("plugins.install")) {
                NotificationCenter.default.post(name: .explorerInstallPlugin, object: nil)
            }

            Button(L10n.tr("settings.plugins.reload")) {
                NotificationCenter.default.post(name: .explorerReloadPlugins, object: nil)
            }

            Button(L10n.tr("settings.plugins.reveal")) {
                NotificationCenter.default.post(name: .explorerRevealPlugins, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let explorerNewTab = Notification.Name("explorerNewTab")
    static let explorerGoBack = Notification.Name("explorerGoBack")
    static let explorerGoForward = Notification.Name("explorerGoForward")
    static let explorerGoUp = Notification.Name("explorerGoUp")
    static let explorerRefresh = Notification.Name("explorerRefresh")
    static let explorerPathInvalid = Notification.Name("explorerPathInvalid")
    static let explorerNewFolder = Notification.Name("explorerNewFolder")
    static let explorerNewFile = Notification.Name("explorerNewFile")
    static let explorerCopy = Notification.Name("explorerCopy")
    static let explorerCut = Notification.Name("explorerCut")
    static let explorerPaste = Notification.Name("explorerPaste")
    static let explorerDuplicate = Notification.Name("explorerDuplicate")
    static let explorerCopyPath = Notification.Name("explorerCopyPath")
    static let explorerGetInfo = Notification.Name("explorerGetInfo")
    static let explorerTrash = Notification.Name("explorerTrash")
    static let explorerToggleHidden = Notification.Name("explorerToggleHidden")
    static let explorerToggleDualPane = Notification.Name("explorerToggleDualPane")
    static let explorerInstallPlugin = Notification.Name("explorerInstallPlugin")
    static let explorerReloadPlugins = Notification.Name("explorerReloadPlugins")
    static let explorerRevealPlugins = Notification.Name("explorerRevealPlugins")
    static let explorerPluginInstallFailed = Notification.Name("explorerPluginInstallFailed")
}
