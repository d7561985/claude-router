#!/bin/zsh
# Installs Claude Router and the "Claude 2" icon into ~/Applications. Run again to update them.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
APPS="$HOME/Applications"
LAUNCHER="$APPS/Claude 2.app"
CLAUDE="/Applications/Claude.app"

[ -d "$CLAUDE" ] || { echo "No $CLAUDE — install the Claude app first."; exit 1; }
command -v swiftc >/dev/null || { echo "No swiftc — install the Command Line Tools: xcode-select --install"; exit 1; }
mkdir -p "$APPS"

# 1. The router
pkill -x "Claude Router" 2>/dev/null || true
"$REPO/build.sh"

# 2. The "Claude 2" icon: the script with the path to this folder's sync-profile.sh
SCRIPT="$(mktemp -t claude2).applescript"
sed "s|__SYNC_SCRIPT__|$REPO/sync-profile.sh|" "$REPO/claude2-launcher.applescript" > "$SCRIPT"
if [ -d "$LAUNCHER" ]; then
  osacompile -o "$LAUNCHER/Contents/Resources/Scripts/main.scpt" "$SCRIPT"
else
  osacompile -o "$LAUNCHER" "$SCRIPT"
  plutil -replace CFBundleIdentifier -string local.claude2.launcher "$LAUNCHER/Contents/Info.plist"
fi
rm -f "$SCRIPT"
cp "$CLAUDE/Contents/Resources/electron.icns" "$LAUNCHER/Contents/Resources/applet.icns"
codesign --force --sign - "$LAUNCHER"
touch "$LAUNCHER"

# 3. Start the router
open -g "$APPS/Claude Router.app"

echo
echo "Done. The second Claude window is the \"Claude 2\" icon in ~/Applications (you can drag it to the Dock)."
echo "Check: \"$APPS/Claude Router.app/Contents/MacOS/Claude Router\" --status"
