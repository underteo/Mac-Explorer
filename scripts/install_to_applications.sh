#!/bin/sh
# Build Release, sign with Apple Development (stable TCC identity), install to /Applications.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

TEAM="${DEVELOPMENT_TEAM:-H567X35N93}"
IDENTITY="${CODE_SIGN_IDENTITY:-Apple Development: matteo.cazzoli@gmail.com (DNZA73X6PP)}"
DEST="/Applications/Mac Explorer.app"

echo "Building Release (team $TEAM)…"
xcodebuild \
  -project "$ROOT/MacExplorer.xcodeproj" \
  -scheme MacExplorer \
  -configuration Release \
  -destination 'platform=macOS' \
  -quiet \
  build \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic

APP="$(ls -td "$HOME/Library/Developer/Xcode/DerivedData/MacExplorer-"*/Build/Products/Release/MacExplorer.app 2>/dev/null | head -1)"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "Build product not found" >&2
  exit 1
fi

rm -rf "$DEST"
cp -R "$APP" "$DEST"
codesign --force --deep --options runtime --sign "$IDENTITY" "$DEST"
echo "Installed: $DEST"
echo "Firma: $(codesign -dv "$DEST" 2>&1 | grep TeamIdentifier || true)"
echo ""
echo "Se macOS ripete i prompt: Impostazioni di Sistema → Privacy e sicurezza → Accesso disco completo"
echo "→ rimuovi eventuali copie vecchie di Mac Explorer, poi riaggiungi solo:"
echo "  $DEST"
echo "Poi apri SEMPRE quell’app (non la build di Xcode/DerivedData)."
