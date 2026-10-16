#!/bin/sh
# Build a distributable Mac Explorer.app (plugins folder is NOT bundled — stays empty for end users).
# Always ad-hoc signed (CODE_SIGN_IDENTITY=-) — same identity as install_to_applications.sh and CI.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT="${ROOT}/dist"
APP_NAME="Mac Explorer.app"
CONFIGURATION="${CONFIGURATION:-Release}"
ENTITLEMENTS="$ROOT/MacExplorer/MacExplorer.entitlements"
# Fixed identity for every packaged build (CI + local).
SIGN_IDENTITY="-"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "Building ${CONFIGURATION} (ad-hoc sign)..."
xcodebuild \
  -project "$ROOT/MacExplorer.xcodeproj" \
  -scheme MacExplorer \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$OUT/DerivedData" \
  build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  DEVELOPMENT_TEAM=

BUILT="$(find "$OUT/DerivedData/Build/Products" -maxdepth 2 -name 'MacExplorer.app' -type d | head -1)"
if [ -z "$BUILT" ] || [ ! -d "$BUILT" ]; then
  echo "Build product not found" >&2
  exit 1
fi

DEST="$OUT/$APP_NAME"
rm -rf "$DEST"
cp -R "$BUILT" "$DEST"

# Ensure we never ship a pre-populated user Plugins directory inside the bundle.
rm -rf "$DEST/Contents/Plugins" \
       "$DEST/Contents/Resources/Plugins" \
       "$DEST/Contents/SharedSupport/Plugins" 2>/dev/null || true

# Re-sign after copy so the shipped app always has the same ad-hoc identity
# (avoids Xcode/Automatic picking Apple Development when a cert is present locally).
codesign --force --deep --options runtime \
  --sign "$SIGN_IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$DEST"

VERIFY="$(codesign -dv --verbose=4 "$DEST" 2>&1 || true)"
echo "$VERIFY" | grep -E '^(Identifier|Format|Signature|Flags|TeamIdentifier)=' || true
case "$VERIFY" in
  *Signature=adhoc*)
    echo "Signing OK: ad-hoc (Signature=adhoc)"
    ;;
  *)
    echo "Expected ad-hoc signature, got:" >&2
    echo "$VERIFY" >&2
    exit 1
    ;;
esac

# Marker for humans inspecting the package: runtime plugins live outside the app.
mkdir -p "$OUT/NOTES"
cat > "$OUT/NOTES/PLUGINS.txt" <<'EOF'
Mac Explorer does not ship any plugins inside the .app.

On first launch the app creates an empty folder:

  ~/Library/Application Support/Mac Explorer/Plugins/

Install plugins later via: Plugins → Install Plugin…
Source examples (optional) live only in the git repo under Examples/.
EOF

(
  cd "$OUT"
  ditto -c -k --keepParent "$APP_NAME" "MacExplorer-macOS.zip"
)

echo "Ready:"
echo "  $DEST"
echo "  $OUT/MacExplorer-macOS.zip"
echo "Plugins are NOT included — end users get an empty Plugins folder."
