#!/bin/bash
set -e

# Generate Sparkle appcast.xml for LocalWhisper
# Usage: ./generate-appcast.sh <version> <download-url> [release-notes]

VERSION="${1:-1.0.0}"
DOWNLOAD_URL="${2:-https://github.com/yourusername/local-whisper/releases/download/v$VERSION/LocalWhisper-$VERSION.zip}"
RELEASE_NOTES="${3:-Bug fixes and improvements.}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
ZIP_FILE="$DIST_DIR/LocalWhisper-$VERSION.zip"
APPCAST_FILE="$PROJECT_DIR/appcast.xml"

echo "📝 Generating appcast.xml for version $VERSION"

# Check if ZIP exists
if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ Error: $ZIP_FILE not found. Run release.sh first."
    exit 1
fi

# Get file size
FILE_SIZE=$(stat -f%z "$ZIP_FILE" 2>/dev/null || stat -c%s "$ZIP_FILE")

# Get current date in RFC 822 format
PUB_DATE=$(date -R 2>/dev/null || date "+%a, %d %b %Y %H:%M:%S %z")

# Generate appcast.xml
cat > "$APPCAST_FILE" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>LocalWhisper Updates</title>
        <link>https://github.com/yourusername/local-whisper</link>
        <description>Most recent updates to LocalWhisper</description>
        <language>en</language>
        <item>
            <title>Version $VERSION</title>
            <description><![CDATA[
                <h2>What's New in $VERSION</h2>
                <p>$RELEASE_NOTES</p>
            ]]></description>
            <pubDate>$PUB_DATE</pubDate>
            <enclosure 
                url="$DOWNLOAD_URL"
                sparkle:version="$VERSION"
                sparkle:shortVersionString="$VERSION"
                length="$FILE_SIZE"
                type="application/octet-stream"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
EOF

echo "✅ Generated $APPCAST_FILE"
echo ""
echo "Next steps:"
echo "1. Update the download URL in appcast.xml to your actual GitHub release URL"
echo "2. Commit and push appcast.xml to your repository"
echo "3. Create a GitHub release and upload LocalWhisper-$VERSION.zip"
echo ""
echo "For signed updates (recommended), you'll need to:"
echo "1. Generate an EdDSA key pair using Sparkle's generate_keys tool"
echo "2. Add the public key to Info.plist (SUPublicEDKey)"
echo "3. Sign the ZIP file and add sparkle:edSignature to appcast.xml"
