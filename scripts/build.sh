#!/bin/sh
# Debug build (uses full Xcode, not Command Line Tools).
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$ROOT"
exec xcodebuild \
  -project "$ROOT/MacExplorer.xcodeproj" \
  -scheme MacExplorer \
  -configuration Debug \
  -destination 'platform=macOS' \
  build \
  "$@"
