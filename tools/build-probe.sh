#!/bin/sh
# Builds tools/build/BLEProbe.app from tools/ble-probe.swift (see that file for usage).
set -eu
cd "$(dirname "$0")"
APP=build/BLEProbe.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.flexbar.probe</string>
<key>CFBundleName</key><string>BLEProbe</string>
<key>CFBundleExecutable</key><string>BLEProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>NSBluetoothAlwaysUsageDescription</key><string>Sends test frames to JBL earbuds.</string>
</dict></plist>
EOF
swiftc -O -swift-version 5 ble-probe.swift -o "$APP/Contents/MacOS/BLEProbe"
codesign --force --sign - "$APP"
echo "built tools/$APP"
