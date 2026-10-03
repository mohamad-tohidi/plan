#!/bin/bash
# Builds WhiteboardScrumPlanner and assembles a double-clickable .app bundle.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building (release)…"
swift build -c release

BIN=".build/release/WhiteboardScrumPlanner"
APP="build/WhiteboardScrumPlanner.app"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$BIN" "$APP/Contents/MacOS/WhiteboardScrumPlanner"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>WhiteboardScrumPlanner</string>
	<key>CFBundleIdentifier</key>
	<string>com.mysake.whiteboard-scrum-planner</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Whiteboard Scrum Planner</string>
	<key>CFBundleDisplayName</key>
	<string>Whiteboard Scrum Planner</string>
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
codesign --force --sign - "$APP" 2>/dev/null || true

echo "==> Done."
echo "    Open it with:  open \"$APP\""
echo "    Or run from terminal:  swift run WhiteboardScrumPlanner"