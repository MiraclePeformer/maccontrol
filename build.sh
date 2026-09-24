#!/bin/bash
# Builds MacControl.app and packages it into a drag-to-install .dmg.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="MacControl"
BUILD="build"
APP="$BUILD/$APP_NAME.app"
STAGE="$BUILD/dmg"
DMG="$BUILD/$APP_NAME.dmg"

echo "==> Cleaning"
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$STAGE"

SOURCES=(Sources/*.swift)

echo "==> Compiling (universal arm64 + x86_64)"
swiftc -O \
    -target arm64-apple-macos13.0 \
    -o "$BUILD/${APP_NAME}_arm64" \
    "${SOURCES[@]}" -framework Cocoa
swiftc -O \
    -target x86_64-apple-macos13.0 \
    -o "$BUILD/${APP_NAME}_x86_64" \
    "${SOURCES[@]}" -framework Cocoa
lipo -create -output "$APP/Contents/MacOS/$APP_NAME" \
    "$BUILD/${APP_NAME}_arm64" "$BUILD/${APP_NAME}_x86_64"
rm -f "$BUILD/${APP_NAME}_arm64" "$BUILD/${APP_NAME}_x86_64"

echo "==> Assembling app bundle"
cp Info.plist "$APP/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "$APP/Contents/Info.plist" 2>/dev/null || true
fi

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP"

echo "==> Building .dmg"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo ""
echo "Done. Installer: $DMG"
