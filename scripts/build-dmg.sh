#!/bin/bash
set -euo pipefail

# Build Beakon DMG for distribution
# Usage: ./scripts/build-dmg.sh

APP_NAME="Beakon"
SCHEME="Beakon"
PROJECT="Beakon/Beakon.xcodeproj"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}.dmg"
VERSION=$(grep -A1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" | head -1 | tr -dc '0-9.')

echo "=== Building $APP_NAME v$VERSION ==="

# Clean build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive
echo "→ Archiving..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    -quiet

# Export
echo "→ Exporting..."
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportPath "$BUILD_DIR/export" \
    -exportOptionsPlist scripts/export-options.plist \
    -quiet 2>/dev/null || {
    # Fallback: copy from archive directly
    echo "→ Using archive app directly..."
    cp -R "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$BUILD_DIR/"
}

APP_PATH="$BUILD_DIR/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$BUILD_DIR/export/$APP_NAME.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed — app not found"
    exit 1
fi

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

echo ""
echo "✅ $BUILD_DIR/$DMG_NAME created"
echo "   Version: $VERSION"
echo "   Size: $(du -h "$BUILD_DIR/$DMG_NAME" | cut -f1)"
