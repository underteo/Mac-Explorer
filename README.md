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

Or from the terminal (scripts set `DEVELOPER_DIR` to Xcode.app so CLT is not used):

```bash
./scripts/build.sh
./scripts/test.sh
./scripts/install_to_applications.sh   # Release → /Applications, ad-hoc (same as package)
```

Run in Xcode with **⌘R**.

## Features

### Browsing

- Sidebar: Favorites and Locations above Recents; visibility and **order** in Settings → Sidebar; location rows use **system folder/volume icons** (`NSWorkspace`)
- View modes: **icons (grid)**, **list** (outline: expand folders in place, open-folder icon when expanded), **columns** (Finder-style drill-down); dual-pane can use a different mode per pane
- List and columns use **alternating row colors** (system `alternatingContentBackgroundColors`)
- Toolbar is stable (no buttons that appear/disappear): empty Trash and pane transfer stay visible but disabled when N/A; view/sort/favorite always present
- **Share / Tags / More** live beside the path bar (not mixed into the window toolbar capsule)
- Sort, search (current folder or this Mac — Settings → Advanced), show hidden files
- Editable path bar in a capsule (click to edit, Return / ⌘A while editing); no focus steal on open
- Back / forward / up, tabs; folders open **in-pane** (tabs preference does not hijack double-click / column drill)

### File operations

- New folder / file templates, rename, duplicate, copy / cut / paste, Trash
- Get Info, copy path, Open With (Launch Services)
- Optional dual pane with copy / move between panes (source = active selection)
- Finder **color tags** (same `tagNames` as Finder): semantic **system colors** (`systemRed`…`systemPurple`), dots next to names, icon wash, assign popover, menu dots (no disclosure chevron on sort / more)
- Extra actions via menu bar **Azioni** and/or context menu (see Settings → Menu): compress, make alias, Quick Look, open in other pane, Terminal at folder, …

### Settings

- **General** — language, zoom, new-window location, open folders in tabs, privacy links (FDA)
- **Sidebar** — show/hide and reorder items
- **Advanced** — Finder-like options: show extensions, rename/extension warnings, iCloud / empty-Trash warnings, Trash after 30 days (syncs Finder preference when possible), keep folders on top, default search scope
- **Menu** — for each action choose **Context** (right-click), **Actions menu**, **Both**, or **Hidden**. Right-click → **Settings…** / **Impostazioni…** opens this tab
- **Plugins** — enable / disable, reload, reveal folder

### Extensibility

- Menu bar commands and keyboard shortcuts
- Out-of-process plugins with hot reload; install from **Plugins → Install Plugin…**

## Install / share

Full guide: [Docs/INSTALL.md](Docs/INSTALL.md)

| Who | What |
|-----|------|
| **Friend / tester** | Download `MacExplorer-macOS.zip` from [Releases](https://github.com/underteo/Mac-Explorer/releases) → Applications → right-click → Open |
| **You, package for others** | `./scripts/package_app.sh` → zip in `dist/` (gitignored), or `git tag v0.x.y && git push --tags` (Actions uploads the Release) |
| **You, daily local install** | `./scripts/install_to_applications.sh` |

Repo: https://github.com/underteo/Mac-Explorer (public source). **No plugins** are bundled; first launch creates `~/Library/Application Support/Mac Explorer/Plugins/`.

## Plugins (optional)

Examples under `Examples/` are **source-only** (for developers). They are not installed with the app.

To add one later: **Plugins → Install Plugin…** and pick e.g. `Examples/Cursor`, or use Settings → Plugins.

Authoring guide: [Docs/CreatingPlugins.md](Docs/CreatingPlugins.md) · API: [Docs/PluginAPI.md](Docs/PluginAPI.md)

## Signing / notarization

Local install and packaged builds both use ad-hoc signing (`CODE_SIGN_IDENTITY=-`) unless you configure Developer ID + notarization yourself.

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
| FDA / Library / Desktop prompts every reinstall | Launching DerivedData/Debug copies confuses TCC. Always install with `./scripts/install_to_applications.sh` and open only `/Applications/Mac Explorer.app` (same path + bundle ID + ad-hoc). Grant once there; remove duplicate Privacy entries. |
| Context menu too crowded / missing items | Settings → Menu (or right-click → Settings…) |
