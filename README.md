# Mac Explorer

Native macOS file manager (SwiftUI) for macOS Tahoe. Outside App Store, **App Sandbox OFF**. Bundle ID: `com.thehordeforge.MacExplorer`.

## Requirements

- macOS Tahoe (deployment target 26.0+)
- Xcode 27.1+

## Setup

If `xcodebuild` complains about Command Line Tools, either:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

or (requires your password):

```bash
sudo /usr/bin/xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Open the project:

```bash
open "/Users/matteocazzoli/IA/Mac Explorer/MacExplorer.xcodeproj"
```

Or build from the terminal:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "/Users/matteocazzoli/IA/Mac Explorer"
xcodebuild -scheme MacExplorer -configuration Debug build
xcodebuild -scheme MacExplorer -configuration Debug test
```

Run in Xcode with **⌘R**.

## Features

### Browsing

- Sidebar: Favorites and Locations above Recents; visibility and **order** in Settings → Sidebar
- View modes: **icons (grid)**, **list**, **columns** (Finder-style); dual-pane can use a different mode per pane
- Sort, search (current folder or this Mac — Settings → Advanced), show hidden files
- Editable path bar in a capsule (click to edit, Return to go); no focus steal on open
- Back / forward / up, tabs

### File operations

- New folder / file templates, rename, duplicate, copy / cut / paste, Trash
- Get Info, copy path, Open With (Launch Services)
- Optional dual pane with copy / move between panes (source = active selection)
- Finder **color tags** (same `tagNames` as Finder); toggle from the context menu
- Extra actions available via menu bar **Azioni** and/or context menu (see below): compress, make alias, Quick Look, open in other pane, Terminal at folder, …

### Settings

- **General** — language, zoom, new-window location, open folders in tabs, privacy links (FDA)
- **Sidebar** — show/hide and reorder items
- **Advanced** — Finder-like options: show extensions, rename/extension warnings, iCloud / empty-Trash warnings, Trash after 30 days (syncs Finder preference when possible), keep folders on top, default search scope
- **Menu** — for each action choose **Context** (right-click), **Actions menu**, or **Hidden**. Right-click → **Settings…** / **Impostazioni…** opens this tab
- **Plugins** — enable / disable, reload, reveal folder

### Extensibility

- Menu bar commands and keyboard shortcuts
- Out-of-process plugins with hot reload; install from **Plugins → Install Plugin…**

## Install (end users)

```bash
./scripts/package_app.sh
# → dist/Mac Explorer.app  and  dist/MacExplorer-macOS.zip
```

Copy `Mac Explorer.app` to `/Applications`. **No plugins are bundled.** On first launch the app creates an empty:

`~/Library/Application Support/Mac Explorer/Plugins/`

## Plugins (optional)

Examples under `Examples/` are **source-only** (for developers). They are not installed with the app.

To add one later: **Plugins → Install Plugin…** and pick e.g. `Examples/Cursor`, or use Settings → Plugins.

Authoring guide: [Docs/CreatingPlugins.md](Docs/CreatingPlugins.md) · API: [Docs/PluginAPI.md](Docs/PluginAPI.md)

## Signing / notarization

Packaged builds use ad-hoc signing (`CODE_SIGN_IDENTITY=-`) unless you configure Developer ID + notarization yourself.

## Docs

- [Docs/DECISIONS.md](Docs/DECISIONS.md)
- [Docs/PROMPT.md](Docs/PROMPT.md)
- [Docs/PluginAPI.md](Docs/PluginAPI.md)
- [Docs/CreatingPlugins.md](Docs/CreatingPlugins.md)

## License / ownership

**Proprietary — all rights reserved.** See [`LICENSE`](LICENSE) and [`COPYRIGHT.md`](COPYRIGHT.md).

You may download and read the source for personal evaluation. **Unauthorized redistribution is prohibited.** Write access to the repository is reserved to the copyright holders (The Horde Forge / Matteo Cazzoli).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `xcodebuild` wants CLT | Set `DEVELOPER_DIR` or `xcode-select` to Xcode.app |
| Plugin missing | Check Application Support path and `manifest.json` |
| Permission errors | Expected for protected folders; app reports them without crashing |
| FDA / Library / Desktop prompts every reinstall | Ad-hoc Debug builds get a **new** code signature each time → macOS treats them as a new app. Install with `./scripts/install_to_applications.sh` (Apple Development + Team ID). Grant Full Disk Access once to `/Applications/Mac Explorer.app`, remove duplicate entries, never launch the DerivedData copy. |
| Context menu too crowded / missing items | Settings → Menu (or right-click → Settings…) |
