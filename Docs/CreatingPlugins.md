# Creating Mac Explorer Plugins

> **For humans and coding agents.** Follow this file end-to-end when adding or fixing a plugin.  
> Reference API: [PluginAPI.md](PluginAPI.md). Working samples: `Examples/SamplePlugin`, `Examples/Cursor`.

## Goal

Ship a folder that Mac Explorer loads **out of process** (no in-app code injection). The app scans a directory, builds context-menu items from `manifest.json`, and runs your script or opens a URL.

## Live plugins folder

```text
~/Library/Application Support/Mac Explorer/Plugins/<PluginFolder>/
```

| How to install | What happens |
|----------------|--------------|
| **Plugins → Install Plugin…** | Pick a folder with `manifest.json`; app copies it in, `chmod +x` on the executable, reloads |
| **Settings → Plugins → Install** | Same panel |
| **Drop / copy folder** into the Plugins directory | **Hot reload** (directory watch + reload on app activate) |
| **Plugins → Reload** | Force rescan |
| **Plugins → Show Folder** | Reveal in Finder |

Disabled plugins stay on disk; toggles live in Settings → Plugins.

## Minimum viable plugin

```text
MyPlugin/
  manifest.json    # required
  run.sh           # optional if urlTemplate is set; must be executable
```

### Checklist (agents: do all of these)

1. [ ] Create one self-contained folder under `Examples/<Name>/` (e.g. `Examples/Cursor/`) — all plugin files live **inside** that folder only.
2. [ ] Write valid `manifest.json` (see schema below).
3. [ ] Write `run.sh` with `#!/bin/sh`, `set -eu`, handle `$1` = action id, remaining args = absolute paths.
4. [ ] `chmod +x run.sh`.
5. [ ] If menu titles should be localized in the app UI, add `plugin.<id>.*` keys to **both** `en.lproj` and `it.lproj` `Localizable.strings`, and use those keys as `name` / `title` strings in the manifest.
6. [ ] Install via **Plugins → Install Plugin…** (or copy into the live folder) and confirm the submenu appears on a matching selection.
7. [ ] Document the plugin in `README.md` Examples list if it ships with the repo.

## manifest.json schema

```json
{
  "id": "com.example.myplugin",
  "name": "plugin.myplugin.name",
  "version": "1.0.0",
  "match": {
    "extensions": ["txt", "md"],
    "foldersOnly": false,
    "filesOnly": false,
    "requireMultiSelect": false,
    "allowMultiSelect": true
  },
  "menu": [
    {
      "type": "action",
      "id": "run",
      "title": "plugin.myplugin.run",
      "action": "run"
    },
    {
      "type": "submenu",
      "title": "plugin.myplugin.more",
      "children": [
        {
          "type": "action",
          "id": "other",
          "title": "plugin.myplugin.other",
          "action": "other"
        }
      ]
    }
  ],
  "executable": "run.sh",
  "urlTemplate": null
}
```

### Field rules

| Field | Required | Notes |
|-------|----------|--------|
| `id` | yes | Stable unique id (reverse-DNS). Used for enable/disable persistence. |
| `name` | yes | Menu root label. Plain text **or** app localization key (`plugin.…`). |
| `version` | yes | Free-form string. |
| `match` | yes | Object; may be `{}` (any non-empty selection). Empty selection → plugin never shows. |
| `menu` | yes | Array of `action` / `submenu` nodes. |
| `executable` | no* | Path **relative to the plugin folder**. Absolute paths outside the folder are **rejected**. |
| `urlTemplate` | no* | Optional URL; `{path}` / `{paths}` replaced with percent-encoded selection. |

\* At least one of `executable` or `urlTemplate` must work for actions to succeed.

### `match` semantics

- Selection **must be non-empty**.
- `requireMultiSelect: true` → need ≥ 2 items.
- `allowMultiSelect: false` → at most 1 item.
- `foldersOnly` / `filesOnly` → all items must be folders / files.
- `extensions: ["png"]` → every **file** must match (no leading dot); folders only allowed if `foldersOnly` is also true.

Matching is evaluated **once per plugin**, not per menu action. Enforce action-specific rules inside `run.sh` (e.g. diff needs exactly two files).

### Menu nodes

**Action**

```json
{ "type": "action", "id": "echo", "title": "Echo", "action": "echo" }
```

- `id`: stable.
- `title`: UI string or localization key.
- `action`: passed to the script as argv[1]; defaults to `id` if omitted at runtime.

**Submenu**

```json
{ "type": "submenu", "title": "More", "children": [ /* actions or nested submenus */ ] }
```

## Execution contract

```text
./run.sh <action> <absPath1> [absPath2...]
```

- Working directory = plugin folder.
- Paths are absolute filesystem paths of the current selection.
- Exit `0` on success. Non-zero is fine; the app does not parse stdout (log to a file or `osascript` alerts if you need UI).
- Prefer `/bin/sh` portability: quote paths, avoid bash-only features unless you set `#!/bin/bash`.

### Skeleton `run.sh`

```sh
#!/bin/sh
set -eu
action="${1:-}"
shift || true
[ -n "$action" ] || exit 1
[ "$#" -gt 0 ] || exit 1

case "$action" in
  run)
    # "$1" … selected paths
    ;;
  *)
    echo "Unknown action: $action" >&2
    exit 1
    ;;
esac
```

### URL-only plugins

Omit `executable` and set e.g.:

```json
"urlTemplate": "myapp://open?path={path}"
```

`{paths}` is a comma-joined list of paths (percent-encoded).

## Localization (optional but recommended)

App menus call `L10n.tr(title)`. If `title` is a key present in String tables, it translates; otherwise the raw string is shown.

Add to **both**:

- `MacExplorer/Resources/en.lproj/Localizable.strings`
- `MacExplorer/Resources/it.lproj/Localizable.strings`

```text
"plugin.myplugin.name" = "My Plugin";
"plugin.myplugin.run" = "Do Thing";
```

## Security constraints (do not fight these)

1. Executable must resolve **inside** the plugin folder (path traversal → load/run error).
2. Plugins are **out of process** only — no Swift code loaded into Mac Explorer.
3. Sandbox is OFF for the host app, but your script still runs as the user: do not escalate privileges.
4. Never ship secrets in the plugin folder.

## Verify quickly

```bash
# Validate JSON
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' Examples/MyPlugin/manifest.json

# Manual script smoke test
Examples/MyPlugin/run.sh run /tmp

# Install into live folder (or use the app menu)
cp -R Examples/MyPlugin "$HOME/Library/Application Support/Mac Explorer/Plugins/MyPlugin"
chmod +x "$HOME/Library/Application Support/Mac Explorer/Plugins/MyPlugin/run.sh"
```

Then right-click a matching file/folder in Mac Explorer → your plugin submenu.

## Agent anti-patterns

- Putting `run.sh` outside the plugin folder or using `/usr/bin/...` as `executable`.
- Forgetting `chmod +x`.
- Assuming empty-area clicks pass no path: the host injects the **current pane folder** as the selection for plugins.
- Adding only English strings when using `plugin.*` keys.
- Claiming the plugin works without installing into the live Plugins directory or using **Install Plugin…**.

## See also

- [PluginAPI.md](PluginAPI.md) — short reference
- `Examples/SamplePlugin` — minimal logger
- `Examples/Cursor` — real-world Cursor CLI integration (canonical folder layout)
