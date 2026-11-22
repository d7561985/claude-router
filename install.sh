#!/bin/zsh
# Ставит Claude Router и значок «Claude 2» в ~/Applications. Повторный запуск обновляет их.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
APPS="$HOME/Applications"
LAUNCHER="$APPS/Claude 2.app"
CLAUDE="/Applications/Claude.app"

[ -d "$CLAUDE" ] || { echo "Нет $CLAUDE — сначала поставьте приложение Claude."; exit 1; }
command -v swiftc >/dev/null || { echo "Нет swiftc — поставьте Command Line Tools: xcode-select --install"; exit 1; }
mkdir -p "$APPS"

# 1. Роутер
pkill -x "Claude Router" 2>/dev/null || true
"$REPO/build.sh"

# 2. Значок «Claude 2»: скрипт с путём к sync-profile.sh этой папки
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

# 3. Запустить роутер
open -g "$APPS/Claude Router.app"

echo
echo "Готово. Второе окно Claude — значок «Claude 2» в ~/Applications (можно перетащить в Dock)."
echo "Проверка: \"$APPS/Claude Router.app/Contents/MacOS/Claude Router\" --status"
