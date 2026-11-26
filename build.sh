#!/bin/sh
# Builds build/FlexBar.app.
#
#   ./build.sh                 build for this Mac's architecture
#   ./build.sh --install       build, copy to /Applications and launch
#   ./build.sh --release       universal build (Apple silicon + Intel) zipped to build/FlexBar.zip
#
# VERSION=1.2.3 ./build.sh --release sets the version shown in Finder (default: from Info.plist).
set -eu
cd "$(dirname "$0")"

MODE="${1:-}"
APP=build/FlexBar.app
rm -rf "$APP" build/FlexBar.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
if [ -n "${VERSION:-}" ]; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
fi

compile() {  # compile <arch> <output>
    swiftc -O -swift-version 5 -parse-as-library \
        -target "$1-apple-macos13.0" \
        Sources/*.swift \
        -o "$2"
}

if [ "$MODE" = "--release" ]; then
    mkdir -p build/arch
    compile arm64 build/arch/FlexBar-arm64
    compile x86_64 build/arch/FlexBar-x86_64
    lipo -create build/arch/FlexBar-arm64 build/arch/FlexBar-x86_64 -output "$APP/Contents/MacOS/FlexBar"
else
    compile "$(uname -m)" "$APP/Contents/MacOS/FlexBar"
fi

# Ad-hoc signature. macOS asks for Bluetooth permission again whenever the signature changes.
codesign --force --sign - "$APP"
echo "built $APP"

case "$MODE" in
--install)
    pkill -x FlexBar 2>/dev/null || true
    rm -rf /Applications/FlexBar.app
    cp -R "$APP" /Applications/
    open /Applications/FlexBar.app
    echo "installed /Applications/FlexBar.app"
    ;;
--release)
    # ditto keeps the bundle's signature and extended attributes intact, unlike plain zip.
    ditto -c -k --keepParent "$APP" build/FlexBar.zip
    echo "packaged build/FlexBar.zip"
    ;;
esac
