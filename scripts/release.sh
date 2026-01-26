#!/bin/bash
set -e

# LocalWhisper Release Script
# Creates a distributable .app bundle and DMG

VERSION="${1:-1.0.0}"
APP_NAME="LocalWhisper"
BUNDLE_ID="com.localwhisper.app"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "🚀 Building LocalWhisper v$VERSION"
echo "================================"

# Clean previous builds
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Build release version
echo "📦 Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

# Create app bundle structure
echo "📁 Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/LocalWhisper" "$APP_BUNDLE/Contents/MacOS/"

# Copy icon
if [ -f "$PROJECT_DIR/LocalWhisper/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/LocalWhisper/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
elif [ -f "$PROJECT_DIR/LocalWhisper.app/Contents/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/LocalWhisper.app/Contents/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>LocalWhisper needs microphone access to record audio for voice-to-text transcription.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Sign the app (ad-hoc signing for local distribution)
echo "🔐 Signing app (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

# Verify the app
echo "✅ Verifying app bundle..."
codesign --verify --verbose "$APP_BUNDLE"

# Get app size
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo "📊 App size: $APP_SIZE"

# Create DMG
echo "💿 Creating DMG..."
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# Create a temporary directory for DMG contents
DMG_TEMP="$DIST_DIR/dmg_temp"
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create a symlink to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP"

# Also create a ZIP for GitHub releases
echo "📦 Creating ZIP..."
ZIP_NAME="$APP_NAME-$VERSION.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
cd "$DIST_DIR"
zip -r "$ZIP_NAME" "$APP_NAME.app"

# Get final sizes
DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
ZIP_SIZE=$(du -sh "$ZIP_PATH" | cut -f1)

echo ""
echo "================================"
echo "✅ Release build complete!"
echo "================================"
echo ""
echo "📁 Output directory: $DIST_DIR"
echo ""
echo "Files created:"
echo "  • $APP_NAME.app ($APP_SIZE)"
echo "  • $DMG_NAME ($DMG_SIZE)"
echo "  • $ZIP_NAME ($ZIP_SIZE)"
echo ""
echo "To install:"
echo "  1. Open $DMG_NAME"
echo "  2. Drag LocalWhisper to Applications"
echo "  3. Open LocalWhisper from Applications"
echo "  4. Grant Microphone and Accessibility permissions when prompted"
echo ""
echo "For GitHub release, upload: $ZIP_PATH"
