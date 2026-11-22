#!/bin/zsh
# Перед запуском «Claude 2»: подтянуть в его профиль то, что приложение держит отдельно
# в каждой папке профиля, из основного окна. Запускать, только пока второе окно закрыто.
#
# - список сессий — ссылка на папку основного окна (сессии лежат по аккаунтам, поэтому
#   каждое окно видит сессии того аккаунта, в который вошло);
# - MCP приложения (`mcpServers`), переключатели инструментов MCP, установленные
#   расширения — копия: приложение пишет часть файлов через временный файл и
#   переименование, ссылка на файл после первой записи стала бы копией;
# - папки расширений — ссылки.
#
# Печатает «same-account», если по последнему входу оба окна в одном аккаунте.
set -euo pipefail
SUPPORT="$HOME/Library/Application Support"
MAIN="$SUPPORT/Claude"
SECOND="$SUPPORT/${1:-Claude-2}"

[ -d "$SECOND" ] || mkdir -p "$SECOND"

link_dir() {
  local name="$1"
  [ -e "$MAIN/$name" ] || return 0
  if [ -L "$SECOND/$name" ]; then return 0; fi
  if [ -e "$SECOND/$name" ]; then
    echo "оставляю свою папку второго окна: $name" >&2
    return 0
  fi
  ln -s "$MAIN/$name" "$SECOND/$name"
}

copy_file() {
  local name="$1"
  [ -f "$MAIN/$name" ] && cp -p "$MAIN/$name" "$SECOND/$name" || true
}

link_dir "claude-code-sessions"
link_dir "Claude Extensions"
link_dir "Claude Extensions Settings"
copy_file "mcp-user-tool-toggles.json"
copy_file "extensions-installations.json"
copy_file "extensions-blocklist.json"

/usr/bin/python3 -I - "$MAIN" "$SECOND" <<'EOF'
import json, os, sys
main, second = sys.argv[1], sys.argv[2]

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}

src = load(os.path.join(main, "claude_desktop_config.json"))
dst_path = os.path.join(second, "claude_desktop_config.json")
dst = load(dst_path)
if dst.get("mcpServers") != src.get("mcpServers", {}):
    dst["mcpServers"] = src.get("mcpServers", {})
    tmp = dst_path + ".sync"
    with open(tmp, "w") as f:
        json.dump(dst, f, ensure_ascii=False, indent=2)
    os.replace(tmp, dst_path)

a = load(os.path.join(main, "config.json")).get("lastKnownAccountUuid")
b = load(os.path.join(second, "config.json")).get("lastKnownAccountUuid")
if a and a == b:
    print("same-account")
EOF
