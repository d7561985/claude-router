#!/bin/zsh
# Before "Claude 2" starts: bring into its profile, from the main window, what the app keeps
# separately in each profile folder. Run only while the second window is closed.
#
# - the session list is a link to the main window's folder (sessions are stored per account,
#   so each window sees the sessions of the account it is signed in to);
# - the app's MCP servers (`mcpServers`), MCP tool toggles and installed extensions are
#   copies: the app writes some files through a temporary file and a rename, so a link to a
#   file would turn into a copy after the first write;
# - the extension folders are links.
#
# Prints "same-account" if both windows were last signed in to the same account.
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
    echo "keeping the second window's own folder: $name" >&2
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
