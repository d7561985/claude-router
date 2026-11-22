# Claude Router

English · [Русский](README.ru.md) · [Deutsch](README.de.md) · [Français](README.fr.md)

Run two windows of the Claude desktop app for macOS side by side, each signed in to its own account.
Google and SSO sign-in work in both, and sessions, skills, plugins and MCP servers are shared.

> Unofficial tool. It relies on how the Claude app works today (the `--user-data-dir` flag, profile
> folders, `claude://` links); an app update may change that.

## Install

Requires macOS 13+, the Claude app in `/Applications` and the Command Line Tools
(`xcode-select --install`).

```bash
git clone https://github.com/d7561985/claude-router.git ~/projects/claude-router
```

```bash
~/projects/claude-router/install.sh
```

This creates `~/Applications/Claude Router.app` and the `~/Applications/Claude 2.app` icon — you can
drag it to the Dock. Run `install.sh` again to update both.

## Usage

1. The main window is the regular Claude app.
2. The second window is the "Claude 2" icon. It starts the router, brings the main window's sessions,
   MCP servers and extensions into the second window's profile, and opens the second window.
3. When both windows are open and a `claude://` link arrives (for example, the reply of a Google or
   SSO sign-in), the router asks which window should open it. When signing in to the second window,
   choose "Claude 2".

One rule: **one account in one window at a time.** The app has no protection against two windows
working on the same session. If both windows were last signed in to the same account, the "Claude 2"
icon warns you.

After a restart nothing needs to be started by hand: the "Claude 2" icon starts the router itself.
While only the main window is open, Claude handles `claude://` links on its own.

Check which app receives the links and which windows are open:

```bash
"$HOME/Applications/Claude Router.app/Contents/MacOS/Claude Router" --status
```

Router log: `~/Library/Logs/Claude Router/router.log` (link parameters are not logged: sign-in replies
carry codes there).

## How it works

**Second window.** `open -n -a Claude --args --user-data-dir=…/Claude-2` starts the app with its own
profile folder: its own sign-in and cookies. The app's single-instance lock is per profile folder, so
the second window does not interfere with the first.

**Sign-in.** The app runs Google and SSO sign-in in the browser and gets the reply back as a
`claude://` link. To macOS both windows are the same app, so the link goes to the main window and the
second one never signs in (the main window's log says
`Google sign-in code does not answer a sign-in this app started; ignoring`). The router is the
`claude://` handler: with two windows open it asks where to send the link and hands it to the chosen
process as an "open URL" event (GURL) addressed by its pid. While Claude is not the handler, the app's
own code may sign in through Apple's sign-in sheet, which returns the reply straight to its window.
Claude makes itself the `claude://` handler again every time it starts, so the router takes it back
every 5 seconds.

**What the windows share:**

- Automatically — `~/.claude` (the app doesn't change this folder): CLAUDE.md, skills,
  `settings.json`, Claude Code plugins, MCP servers from `~/.claude.json` and project `.mcp.json`
  files, memory, conversation files.
- Through `sync-profile.sh`, before each start of "Claude 2": the session list is a link to the main
  window's folder (sessions are stored per account, so each window sees the sessions of its own
  account), the extension folders are links; the app's MCP servers (`mcpServers`), MCP tool toggles
  and the extension list are copies. Copies, not links: the app writes some files through a temporary
  file and a rename, so a link to a file would turn into a copy after the first write. The source is
  the main window: add MCP servers there.
- Can't be linked — what an account keeps on the server: connectors (Gmail, Drive, Calendar),
  plugins enabled on the account, claude.ai chats.

## If the second window offers a different sign-in

A profile can switch to third-party provider mode: sign-in with an Anthropic Console token, no
regular claude.ai sign-in, logs written to `~/Library/Logs/Claude-3p/`. The sign is
`"deploymentMode": "3p"` in `~/Library/Application Support/Claude-2-3p/claude_desktop_config.json`.
Close the second window, set it to `"1p"` there and open the window again with the "Claude 2" icon.

## Uninstall

```bash
pkill -x "Claude Router"; rm -rf "$HOME/Applications/Claude Router.app" "$HOME/Applications/Claude 2.app"
```

Claude becomes the `claude://` handler again the next time it starts. The second window's profile
folder stays in `~/Library/Application Support/Claude-2`; its link to the main window's sessions is
`claude-code-sessions` (removing the link doesn't touch the sessions).

## Files

| File | What it does |
|---|---|
| `main.swift`, `Info.plist`, `build.sh` | the router, `~/Applications/Claude Router.app` |
| `claude2-launcher.applescript` | the "Claude 2" icon |
| `sync-profile.sh` | brings the main window's sessions, MCP servers and extensions into the second window |
| `install.sh` | builds and installs all of the above |

Testing the chooser without the dialog: `defaults write local.claude.router testPick "Claude 2"` —
the next link goes to "Claude 2", then the setting resets.

## License

MIT
