# Mac Explorer — Decisions

| Decision | Value |
|----------|--------|
| Product name | Mac Explorer |
| Bundle ID | `com.thehordeforge.MacExplorer` |
| Deployment target | macOS 26.0 (Tahoe); SDK 27 via Xcode 27.1 |
| Distribution | Outside App Store |
| App Sandbox | **OFF** |
| Folder TCC | No in-app FDA prompts — macOS may ask once natively. Prefer `/Applications/Mac Explorer.app` via `scripts/install_to_applications.sh` (ad-hoc, fixed path + bundle ID) so grants stick across rebuilds. |
| UI language | Default: system (en+it tables). Overridable in Settings → General |
| New window location | Configurable (Recents/Home/…); default Recents |
| Open folders | Prefer tabs (Settings) for some flows; **double-click / column focus always navigates in-pane** (ignores “open in tabs”). |
| Interface zoom | 50%–150% (default 100%), Settings → General |
| View modes | Per-pane: grid / list / columns. List = `NSOutlineView` (expand folders, open-folder icon). Columns = horizontal browser with zebra rows. Toolbar view/sort/favorite always shown (active pane); dual-pane keeps per-pane chrome too. |
| Toolbar | Fixed membership (disabled ≠ hidden): empty Trash, copy/move between panes. Share/Tags/More in path-bar strip (`ExplorerToolbar.swift` / `ExplorerSelectionActionsBar`). |
| Sidebar order | Favorites → locations → Recents by default; user reorder + visibility in Settings → Sidebar; location/favorite icons from `NSWorkspace` |
| Path bar | Always-editable capsule field; no first-responder steal on window open / pane switch |
| Advanced prefs | Finder-aligned toggles in Settings → Advanced (extensions, warnings, Trash 30 days via `com.apple.finder` when possible, folders on top, search scope) |
| Search | Scope: current folder (default) or “this Mac” (home + Applications, capped) |
| Tags | System Finder tags via `URLResourceValues.tagNames`. Colors = semantic `NSColor.system*` (not pastel `fileLabelColors`). Dots + icon wash shared via `FileIconCache` / `FinderTagDots*`. |
| Context vs Actions menu | Configurable per action: **Context** / **Actions** (menu bar Azioni) / **Both** / **Hidden**. Defaults keep the right-click menu lean; extras (compress, alias, Quick Look, Terminal, open in pane, …) start in Azioni. Right-click always includes **Settings…** deep-link to Settings → Menu. Do not clone Finder’s full Services/Continuity menu. |
| Dual-pane transfer | Source = active pane selection; destination = other pane. Toolbar buttons always visible; disabled when single-pane or empty selection. |
| Install script | `scripts/install_to_applications.sh` builds Release, ad-hoc signs, installs to `/Applications`, then removes other DerivedData/dist `.app` copies so only that path is launched. |
| Share / package | `scripts/package_app.sh` → same ad-hoc `.app` + zip under `dist/` (gitignored). Publish via GitHub Releases (`v*` tags / Actions `Package` on `macos-26`). See `Docs/INSTALL.md`. |
| Extensibility | Open With (Launch Services) first; then out-of-process plugins with Settings toggle |
| Plugin location | `~/Library/Application Support/Mac Explorer/Plugins/` (empty on fresh install; examples only in `Examples/` for optional install) |
| Distribution | GitHub public **source-available** + proprietary `LICENSE` (no unauthorized redistribution). Packaged `.app` via `scripts/package_app.sh` does not ship plugins. |
| Dependencies | No external SPM packages |

## Toolchain note

Prefer:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

If system `xcode-select` still points at Command Line Tools, optionally run:

```bash
sudo /usr/bin/xcode-select -s /Applications/Xcode.app/Contents/Developer
```
