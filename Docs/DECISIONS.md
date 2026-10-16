# Mac Explorer — Decisions

| Decision | Value |
|----------|--------|
| Product name | Mac Explorer |
| Bundle ID | `com.thehordeforge.MacExplorer` |
| Deployment target | macOS 26.0 (Tahoe); SDK 27 via Xcode 27.1 |
| Distribution | Outside App Store |
| App Sandbox | **OFF** |
| Folder TCC | Cannot be granted in-app; user enables Full Disk Access (or Files & Folders). First launch prompts once if FDA missing (opens System Settings). Settings → General also links there. Prefer `/Applications` over DerivedData so TCC sticks. |
| UI language | Default: system (en+it tables). Overridable in Settings → General |
| New window location | Configurable (Recents/Home/…); default Recents |
| Open folders | Prefer tabs (Settings); optional navigate in place |
| Interface zoom | 50%–150% (default 100%), Settings → General |
| Extensibility | Open With (Launch Services) first; then out-of-process plugins with Settings toggle |
| Plugin location | `~/Library/Application Support/Mac Explorer/Plugins/` |
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
