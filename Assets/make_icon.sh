#!/bin/bash
# Renders Assets/AppIcon.svg (via the CoreGraphics mirror) and builds
# Assets/AppIcon.icns for the app bundle.
set -euo pipefail
cd "$(dirname "$0")"

ICONSET="AppIcon.iconset"

echo "==> Rendering icon PNGs"
rm -rf "$ICONSET" AppIcon.icns
swift render_icon.swift "$ICONSET"

echo "==> Building AppIcon.icns"
iconutil -c icns "$ICONSET" -o AppIcon.icns

echo "==> Done: $PWD/AppIcon.icns"