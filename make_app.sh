#!/bin/bash
# Builds the `plan` app and installs it into the Applications folder.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="plan"
BUNDLE_ID="dev.plan.board"
BIN=".build/release/$APP_NAME"
BUNDLE="build/$APP_NAME.app"

echo "==> Building (release)…"
swift build -c release

echo "==> Assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc signature keeps Gatekeeper happy when launched locally.
codesign --force --sign - "$BUNDLE" 2>/dev/null || true

echo "==> Installing to Applications"
DEST=""
if [ -w /Applications ]; then
  DEST="/Applications/$APP_NAME.app"
else
  DEST="$HOME/Applications/$APP_NAME.app"
fi
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -R "$BUNDLE" "$DEST"

echo "==> Done."
echo "    Installed: $DEST"
echo "    Run it with:  open \"$DEST\""
echo "    Or run from terminal:  swift run"