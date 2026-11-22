#!/bin/zsh
# Собирает ~/Applications/Claude Router.app из main.swift и Info.plist.
set -euo pipefail
cd "$(dirname "$0")"
APP="$HOME/Applications/Claude Router.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp /Applications/Claude.app/Contents/Resources/electron.icns "$APP/Contents/Resources/electron.icns"
swiftc -O main.swift -o "$APP/Contents/MacOS/Claude Router" -framework AppKit
codesign --force --sign - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "собрано: $APP"
