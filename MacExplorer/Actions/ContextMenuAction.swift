import Foundation

/// Where a file action appears in the UI.
enum MenuActionPlacement: String, CaseIterable, Identifiable, Sendable {
    /// Right-click / control-click context menu.
    case context
    /// App menu bar → Azioni (separate from Finder’s menu).
    case actionsMenu
    /// Not shown anywhere (action still available via shortcuts if any).
    case hidden

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .context: return L10n.tr("settings.menu.placement.context")
        case .actionsMenu: return L10n.tr("settings.menu.placement.actions")
        case .hidden: return L10n.tr("settings.menu.placement.hidden")
        }
    }
}

/// Configurable file actions (context menu vs Azioni menu vs off).
enum ContextMenuActionID: String, CaseIterable, Identifiable, Sendable {
    case open
    case openWith
    case newFolder
    case newFile
    case openInNewPane
    case paste
    case trash
    case getInfo
    case rename
    case compress
    case duplicate
    case makeAlias
    case quickLook
    case copy
    case cut
    case tags
    case customizeInFinder
    case sortBy
    case showViewOptions
    case folderActionsSetup
    case newTextFile
    case terminalTab
    case terminalWindow
    case copyPath
    case revealInFinder
    case favorites
    case plugins

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: return L10n.tr("action.open")
        case .openWith: return L10n.tr("action.open_with")
        case .newFolder: return L10n.tr("action.new_folder")
        case .newFile: return L10n.tr("action.new_file")
        case .openInNewPane: return L10n.tr("action.open_in_new_pane")
        case .paste: return L10n.tr("action.paste")
        case .trash: return L10n.tr("action.move_to_trash")
        case .getInfo: return L10n.tr("action.get_info")
        case .rename: return L10n.tr("action.rename")
        case .compress: return L10n.tr("action.compress")
        case .duplicate: return L10n.tr("action.duplicate")
        case .makeAlias: return L10n.tr("action.make_alias")
        case .quickLook: return L10n.tr("action.quick_look")
        case .copy: return L10n.tr("action.copy")
        case .cut: return L10n.tr("action.cut")
        case .tags: return L10n.tr("action.tags")
        case .customizeInFinder: return L10n.tr("action.customize_folder")
        case .sortBy: return L10n.tr("action.sort_by")
        case .showViewOptions: return L10n.tr("action.show_view_options")
        case .folderActionsSetup: return L10n.tr("action.folder_actions_setup")
        case .newTextFile: return L10n.tr("action.new_text_file")
        case .terminalTab: return L10n.tr("action.terminal_tab")
        case .terminalWindow: return L10n.tr("action.terminal_window")
        case .copyPath: return L10n.tr("action.copy_path")
        case .revealInFinder: return L10n.tr("action.reveal_finder")
        case .favorites: return L10n.tr("favorites.add")
        case .plugins: return L10n.tr("settings.plugins")
        }
    }

    /// Lean defaults: essentials in context; Finder-like extras in Azioni (or off).
    var defaultPlacement: MenuActionPlacement {
        switch self {
        case .open, .openWith, .newFolder, .newFile, .paste, .trash,
             .getInfo, .rename, .duplicate, .copy, .cut,
             .copyPath, .revealInFinder, .favorites, .plugins, .tags:
            return .context
        case .openInNewPane, .compress, .makeAlias, .quickLook,
             .newTextFile, .terminalTab, .terminalWindow:
            return .actionsMenu
        case .customizeInFinder, .sortBy, .showViewOptions, .folderActionsSetup:
            return .hidden
        }
    }
}
