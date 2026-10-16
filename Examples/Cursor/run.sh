#!/bin/sh
# Mac Explorer plugin: Cursor
# Tutto ciò che serve sta in questa cartella (più il CLI `cursor` sul PATH).
# Invocazione: run.sh <action> <path1> [path2...]

set -eu

action="${1:-}"
shift || true

if [ -z "$action" ] || [ "$#" -eq 0 ]; then
  exit 1
fi

resolve_cursor() {
  if command -v cursor >/dev/null 2>&1; then
    command -v cursor
    return
  fi
  for candidate in \
    "/usr/local/bin/cursor" \
    "$HOME/.local/bin/cursor" \
    "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
  do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  osascript -e 'display alert "Cursor non trovato" message "Installa il comando shell da Cursor: Command Palette → “Shell Command: Install '\''cursor'\'' command in PATH”." as critical' >/dev/null 2>&1 || true
  exit 1
}

CURSOR_BIN="$(resolve_cursor)"

workspace_for() {
  path="$1"
  if [ -d "$path" ]; then
    printf '%s\n' "$path"
  else
    dirname "$path"
  fi
}

first_path="$1"
workspace="$(workspace_for "$first_path")"

notify_missing_diff() {
  osascript -e 'display alert "Confronta in Cursor" message "Seleziona esattamente due file per il diff."' >/dev/null 2>&1 || true
}

case "$action" in
  chat)
    exec "$CURSOR_BIN" -n "$workspace"
    ;;

  agent)
    quoted_ws=$(printf "%s" "$workspace" | sed "s/'/'\\\\''/g")
    quoted_bin=$(printf "%s" "$CURSOR_BIN" | sed "s/'/'\\\\''/g")
    osascript <<EOF
tell application "Terminal"
  activate
  do script "cd '$quoted_ws' && '$quoted_bin' agent --trust --workspace '$quoted_ws'"
end tell
EOF
    ;;

  open)
    exec "$CURSOR_BIN" -n "$@"
    ;;

  open-classic)
    exec "$CURSOR_BIN" -n --classic "$@"
    ;;

  open-reuse)
    exec "$CURSOR_BIN" -r "$@"
    ;;

  add)
    for path in "$@"; do
      "$CURSOR_BIN" -a "$(workspace_for "$path")"
    done
    ;;

  diff)
    if [ "$#" -ne 2 ] || [ -d "$1" ] || [ -d "$2" ]; then
      notify_missing_diff
      exit 1
    fi
    exec "$CURSOR_BIN" -d "$1" "$2"
    ;;

  copy-cli)
    if [ ! -d "$first_path" ] && [ "$#" -eq 1 ]; then
      snippet=$(python3 -c 'import shlex,sys; print("cursor -g " + shlex.quote(sys.argv[1]))' "$first_path")
    else
      snippet=$(python3 -c 'import shlex,sys; print("cursor -n " + shlex.quote(sys.argv[1]))' "$workspace")
    fi
    printf '%s' "$snippet" | pbcopy
    ;;

  *)
    echo "Unknown Cursor plugin action: $action" >&2
    exit 1
    ;;
esac
