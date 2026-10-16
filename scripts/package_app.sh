#!/bin/sh
# Build a distributable Mac Explorer.app (plugins folder is NOT bundled — stays empty for end users).
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT="${ROOT}/dist"
APP_NAME="Mac Explorer.app"
CONFIGURATION="${CONFIGURATION:-Release}"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "Building ${CONFIGURATION}..."
xcodebuild \
  -project "$ROOT/MacExplorer.xcodeproj" \
  -scheme MacExplorer \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$OUT/DerivedData" \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES

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
