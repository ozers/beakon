#!/bin/bash
set -euo pipefail

# Build signed & notarized Beakon DMG for distribution
# Usage: ./scripts/build-dmg.sh

APP_NAME="Beakon"
SCHEME="Beakon"
PROJECT="Beakon/Beakon.xcodeproj"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}.dmg"
SIGN_IDENTITY="Developer ID Application: OZER SUBASI (QGVLTWHNKA)"
NOTARIZE_PROFILE="BeakonNotarize"
VERSION=$(grep -A1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" | head -1 | tr -dc '0-9.')

echo "=== Building $APP_NAME v$VERSION ==="

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive with Developer ID signing
echo "→ Archiving (signed)..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -destination 'generic/platform=macOS' \
    archive \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    -quiet

# Extract app from archive
APP_PATH="$BUILD_DIR/$APP_NAME.app"
cp -R "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$APP_PATH"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed — app not found"
    exit 1
fi

# Verify signing
echo "→ Verifying signature..."
codesign -vvv --deep --strict "$APP_PATH" 2>&1 | head -5

# Create DMG
echo "→ Creating DMG..."
DMG_TEMP="$BUILD_DIR/dmg-temp"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

rm -rf "$DMG_TEMP"

# Sign DMG itself
echo "→ Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" "$BUILD_DIR/$DMG_NAME"

# Notarize
echo "→ Submitting for notarization..."
xcrun notarytool submit "$BUILD_DIR/$DMG_NAME" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait

# Staple
echo "→ Stapling ticket..."
xcrun stapler staple "$BUILD_DIR/$DMG_NAME"

echo ""
echo "✅ $BUILD_DIR/$DMG_NAME created (signed & notarized)"
echo "   Version: $VERSION"
echo "   Size: $(du -h "$BUILD_DIR/$DMG_NAME" | cut -f1)"
