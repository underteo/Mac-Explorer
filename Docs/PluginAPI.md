# Mac Explorer Plugin API

> **Authoring guide (humans + AIs):** [CreatingPlugins.md](CreatingPlugins.md)

Plugins are folders inside:

`~/Library/Application Support/Mac Explorer/Plugins/<PluginName>/`

Each plugin must contain `manifest.json`.

**Install:** menu **Plugins → Install Plugin…**, Settings → Plugins, or copy into the folder (hot-reloaded).

## manifest.json

```json
{
  "id": "com.example.demo",
  "name": "Demo Tools",
  "version": "1.0.0",
  "match": {
    "extensions": ["txt", "md"],
    "foldersOnly": false,
    "filesOnly": true,
    "requireMultiSelect": false,
    "allowMultiSelect": true
  },
  "menu": [
    {
      "type": "submenu",
      "title": "Shortcuts",
      "children": [
        { "type": "action", "id": "echo", "title": "Echo Paths", "action": "echo" }
      ]
    }
  ],
  "executable": "run.sh"
}
```

### Fields

| Field | Description |
|-------|-------------|
| `id` | Stable unique id |
| `name` | Display name in menus and Settings (may be an app localization key) |
| `version` | Free-form version string |
| `match` | When the plugin menu appears |
| `menu` | Tree of `action` / `submenu` nodes |
| `executable` | Path **relative to the plugin folder** (absolute paths outside the folder are rejected) |
| `urlTemplate` | Optional URL opened instead of/in addition to executable; supports `{path}` / `{paths}` |

### Execution model

v1 runs plugins **out of process**:

```text
run.sh <action> <path1> <path2> ...
```

Mac Explorer does not load arbitrary in-process code.

### Empty area (background) clicks

If nothing is selected, Mac Explorer passes the **current folder** of the pane as the plugin selection (so actions like “open chat in this folder” work from the blank list area).

### Enable / disable

Settings → Plugins. Disabled plugins stay on disk but are hidden from context menus.

See `Examples/SamplePlugin` and `Examples/Cursor` for working samples.  
Authoring guide (for humans + AI): [CreatingPlugins.md](CreatingPlugins.md).
