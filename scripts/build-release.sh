#!/usr/bin/env bash
# Build a distributable VarFontStudio.app zip for GitHub Releases (no Xcode required for end users).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="VarFontStudio"
WORKSPACE="VarFontStudio.xcworkspace"
CONFIGURATION="Release"
DERIVED="$ROOT/build/ReleaseDerivedData"
PRODUCTS="$DERIVED/Build/Products/$CONFIGURATION"
APP="$PRODUCTS/VarFontStudio.app"
DIST="$ROOT/dist"

RUN_TESTS=1
if [[ "${1:-}" == "--skip-tests" ]]; then
  RUN_TESTS=0
fi

if [[ $RUN_TESTS -eq 1 ]]; then
  echo "Running swift test…"
  swift test
fi

echo "Building $SCHEME ($CONFIGURATION)…"
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

if [[ ! -d "$APP" ]]; then
  echo "error: build succeeded but app not found at $APP" >&2
  exit 1
fi

"$ROOT/scripts/bundle-python-runtime.sh" "$APP"

echo "Re-signing app bundle…"
/usr/bin/codesign --force --deep --sign - --options runtime "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist" 2>/dev/null || echo "0")"
STAMP="$(date +%Y%m%d)"
ARCH="$(uname -m)"
ZIP_NAME="VarFontStudio-${VERSION}-b${BUILD}-${STAMP}-${ARCH}.zip"

mkdir -p "$DIST"
ZIP_PATH="$DIST/$ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP_PATH"

echo ""
echo "Release artifact: $ZIP_PATH"
echo "Upload this zip to GitHub Releases. Users unzip and drag VarFontStudio.app to Applications."
echo "First launch: if macOS blocks the app, right-click → Open (unsigned/ad-hoc build)."
