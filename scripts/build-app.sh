#!/bin/bash
#
# Builds dyNotch.app from a release build — the app's first .app bundle (Milestone 6.2),
# the enabler for SMAppService launch-at-login. CLT-only (no Xcode); ad-hoc signed.
# Developer-ID signing + notarization is Milestone 6.3.
#
# Usage:  ./scripts/build-app.sh   then   open dyNotch.app
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang swift build -c release

BIN=".build/release"
APP="dyNotch.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

# Executable + the dylib it links (@loader_path rpath → must be beside the binary) go in MacOS/;
# the adapter's resource bundle (run.pl) goes in Resources/ (where codesign expects resource
# bundles). `locateArtifacts()` scans both the executable dir and Resources/ for run.pl.
cp "$BIN/dynotch" "$MACOS/dynotch"
cp "$BIN/libMediaRemoteAdapter.dylib" "$MACOS/"
cp -R "$BIN/MediaRemoteAdapter_MediaRemoteAdapter.bundle" "$RESOURCES/"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.jy26.dynotch</string>
    <key>CFBundleName</key><string>dyNotch</string>
    <key>CFBundleExecutable</key><string>dynotch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc sign, inner code first (M6.2). Real Developer-ID signing + notarization is M6.3.
codesign --force --sign - "$MACOS/libMediaRemoteAdapter.dylib"
codesign --force --sign - "$APP"

echo "Built $APP  (open $APP to run)"
