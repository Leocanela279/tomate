#!/bin/bash
# Builds Tomate in Release and packs it into build/Tomate.dmg (the app plus a link to Applications).
#
#   scripts/make-dmg.sh          version from the project (MARKETING_VERSION)
#   scripts/make-dmg.sh 1.2.0    stamps that version into the app
#
# The app is signed "to run locally" (ad hoc), like in Xcode. That is enough to run it,
# but macOS asks for confirmation the first time; the website explains how.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
BUILD="$PWD/build"
APP="$BUILD/Release/Tomate.app"
STAGE="$BUILD/dmg"
DMG="$BUILD/Tomate.dmg"

rm -rf "$BUILD/Release" "$STAGE" "$DMG"

xcodebuild \
  -project Tomate.xcodeproj \
  -target Tomate \
  -configuration Release \
  SYMROOT="$BUILD" \
  ${VERSION:+MARKETING_VERSION="$VERSION"} \
  -quiet build

codesign --verify --deep --strict "$APP"
echo "Firmado: $(codesign -dv "$APP" 2>&1 | grep -E '^Signature' || true)"

mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Aplicaciones"

hdiutil create -volname "Tomate" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"

echo "Listo: $DMG ($(du -h "$DMG" | cut -f1))"
