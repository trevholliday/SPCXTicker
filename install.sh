#!/bin/zsh
# Builds a release binary, wraps it in SPCXTicker.app, and installs it to /Applications.
set -euo pipefail

cd "$(dirname "$0")"
swift build -c release

APP_NAME="SPCXTicker"
BUNDLE_ID="com.trevholliday.spcxticker"
STAGE="$(mktemp -d)/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp ".build/release/$APP_NAME" "$STAGE/Contents/MacOS/$APP_NAME"

cat > "$STAGE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

if [[ -f "AppIcon.icns" ]]; then
    cp "AppIcon.icns" "$STAGE/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$STAGE/Contents/Info.plist"
fi

codesign --force --sign - "$STAGE"

pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$DEST"
mv "$STAGE" "$DEST"
echo "Installed $DEST"
