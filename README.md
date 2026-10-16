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

- Sidebar locations, favorites, and recent folders
- List/grid browsing, sort, search (current folder), show hidden files
- Editable path bar, back/forward/up, tabs
- New folder/file templates, rename, duplicate, copy/cut/paste, Trash
- Get Info, copy path, Open With (Launch Services)
- Optional dual pane with copy/move between panes
- Menu bar commands and keyboard shortcuts
- Plugins (out of process) with Settings → Plugins enable/disable

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
