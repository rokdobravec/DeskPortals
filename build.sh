#!/bin/bash
# Build DeskPortals.app (Apple Silicon, ad-hoc signed).
#   ./build.sh           → build/DeskPortals.app
#   ./build.sh install   → also copy to ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64

APP=build/DeskPortals.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/DeskPortals "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "install" ]]; then
    mkdir -p "$HOME/Applications"
    ditto "$APP" "$HOME/Applications/DeskPortals.app"
    echo "Installed to ~/Applications/DeskPortals.app"
fi
