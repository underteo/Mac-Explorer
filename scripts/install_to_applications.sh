#!/bin/sh
# Build Release, ad-hoc sign (same as package_app.sh), install to /Applications.
# Always runs xcodebuild (incremental). CLEAN=1 for a full clean rebuild.
# After install, removes other MacExplorer.app products (DerivedData / dist) so
# “Open” always hits /Applications — not an Xcode build path.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

SIGN_IDENTITY="-"
ENTITLEMENTS="$ROOT/MacExplorer/MacExplorer.entitlements"
DEST="/Applications/Mac Explorer.app"
ARCH="$(uname -m)"
CLEAN="${CLEAN:-0}"

filter_xcode_noise() {
  grep -Ev \
    -e 'DVTErrorPresenter' \
    -e 'DVTCoreSimulatorAdditionsErrorDomain' \
    -e 'CoreSimulator' \
    -e 'iOSSimulator:' \
    -e 'Unable to load simulator devices' \
    -e 'Using the first of multiple matching destinations' \
    -e '^\{ platform:macOS' \
    -e '^--$' \
    -e 'Failure Reason: The version of the CoreSimulator' \
    -e 'Recovery Suggestion: Please ensure that you have installed' \
    -e 'most recent version of Xcode supported by macOS' \
    || true
}

product_app() {
  ls -td "$HOME/Library/Developer/Xcode/DerivedData/MacExplorer-"*/Build/Products/Release/MacExplorer.app 2>/dev/null | head -1
}

# Drop every MacExplorer.app that is not the /Applications install.
remove_non_install_apps() {
  removed=0
  # DerivedData Debug/Release/… products (keeps object files for incremental builds).
  for app in "$HOME"/Library/Developer/Xcode/DerivedData/MacExplorer-*/Build/Products/*/MacExplorer.app; do
    if [ -d "$app" ]; then
      rm -rf "$app"
      removed=$((removed + 1))
    fi
  done
  # Local package output, if present.
  if [ -d "$ROOT/dist/Mac Explorer.app" ]; then
    rm -rf "$ROOT/dist/Mac Explorer.app"
    removed=$((removed + 1))
  fi
  if [ -d "$ROOT/dist/MacExplorer.app" ]; then
    rm -rf "$ROOT/dist/MacExplorer.app"
    removed=$((removed + 1))
  fi
  if [ "$removed" -gt 0 ]; then
    echo "Removed $removed non-install .app build(s)"
  fi
}

# Prefer quitting a cleanly signed install before replacing the bundle.
osascript -e 'tell application "Mac Explorer" to quit' >/dev/null 2>&1 || true
sleep 0.2

if [ "$CLEAN" = "1" ]; then
  echo "Clean Release…"
  XCODE_ACTION="clean build"
else
  echo "Building Release…"
  XCODE_ACTION="build"
fi

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
set +e
# shellcheck disable=SC2086
xcodebuild \
  -project "$ROOT/MacExplorer.xcodeproj" \
  -scheme MacExplorer \
  -configuration Release \
  -destination "platform=macOS,arch=${ARCH}" \
  -quiet \
  $XCODE_ACTION \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  DEVELOPMENT_TEAM= \
  >"$LOG" 2>&1
STATUS=$?
set -e
if [ "$STATUS" -ne 0 ]; then
  filter_xcode_noise <"$LOG" >&2
  exit "$STATUS"
fi

APP="$(product_app)"
if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
  echo "Build product not found" >&2
  exit 1
fi

BIN="$APP/Contents/MacOS/MacExplorer"
if [ ! -f "$BIN" ]; then
  echo "Executable missing in build product: $APP" >&2
  exit 1
fi

rm -rf "$DEST"
cp -R "$APP" "$DEST"
codesign --force --deep --options runtime \
  --sign "$SIGN_IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$DEST"

VERIFY="$(codesign -dv --verbose=4 "$DEST" 2>&1 || true)"
case "$VERIFY" in
  *Signature=adhoc*) ;;
  *)
    echo "Expected ad-hoc signature on $DEST" >&2
    echo "$VERIFY" >&2
    exit 1
    ;;
esac

# Delete DerivedData/dist app bundles *after* copy so only /Applications remains.
remove_non_install_apps

STAMP="$(stat -f '%Sm' -t '%H:%M:%S' "$DEST/Contents/MacOS/MacExplorer")"
SIZE="$(stat -f '%z' "$DEST/Contents/MacOS/MacExplorer")"
echo "Installed: $DEST ($STAMP, ${SIZE} bytes, ad-hoc)"
