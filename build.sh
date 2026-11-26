#!/bin/sh
# Builds build/FlexBar.app. With --install, copies it to /Applications and launches it.
set -eu
cd "$(dirname "$0")"

APP=build/FlexBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

swiftc -O -swift-version 5 -parse-as-library \
    -target arm64-apple-macos13.0 \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/FlexBar"

# Ad-hoc signature. macOS asks for Bluetooth permission again whenever the signature changes.
codesign --force --sign - "$APP"
echo "built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x FlexBar 2>/dev/null || true
    rm -rf /Applications/FlexBar.app
    cp -R "$APP" /Applications/
    open /Applications/FlexBar.app
    echo "installed /Applications/FlexBar.app"
fi
