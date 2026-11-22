# Claude Router

[English](README.md) · [Русский](README.ru.md) · Deutsch · [Français](README.fr.md)

Zwei Fenster der Claude-Desktop-App für macOS nebeneinander, jedes mit einem eigenen Konto. Die
Anmeldung über Google und SSO funktioniert in beiden, Sitzungen, Skills, Plugins und MCP-Server sind
gemeinsam.

> Inoffizielles Werkzeug. Es stützt sich darauf, wie die Claude-App heute funktioniert (das Flag
> `--user-data-dir`, Profilordner, `claude://`-Links); ein Update der App kann das ändern.

## Installation

Voraussetzungen: macOS 13+, die Claude-App in `/Applications` und die Command Line Tools
(`xcode-select --install`).

```bash
git clone https://github.com/d7561985/claude-router.git ~/projects/claude-router
```

```bash
~/projects/claude-router/install.sh
```

Danach gibt es `~/Applications/Claude Router.app` und das Symbol `~/Applications/Claude 2.app` — es
lässt sich ins Dock ziehen. Ein erneuter Aufruf von `install.sh` aktualisiert beide.

## Verwendung

1. Das Hauptfenster ist die normale Claude-App.
2. Das zweite Fenster ist das Symbol „Claude 2“. Es startet den Router, übernimmt Sitzungen,
   MCP-Server und Erweiterungen des Hauptfensters in das Profil des zweiten Fensters und öffnet das
   zweite Fenster.
3. Sind beide Fenster offen und trifft ein `claude://`-Link ein (zum Beispiel die Antwort einer
   Anmeldung über Google oder SSO), fragt der Router, welches Fenster ihn öffnen soll. Bei der
   Anmeldung im zweiten Fenster wählen Sie „Claude 2“.

Eine Regel: **ein Konto in nur einem Fenster zur selben Zeit.** Die App schützt nicht davor, dass zwei
Fenster an derselben Sitzung arbeiten. Waren beide Fenster zuletzt mit demselben Konto angemeldet,
warnt das Symbol „Claude 2“.

Nach einem Neustart muss nichts von Hand gestartet werden: Das Symbol „Claude 2“ startet den Router
selbst. Solange nur das Hauptfenster offen ist, verarbeitet Claude `claude://`-Links selbst.

Prüfen, welche App die Links empfängt und welche Fenster offen sind:

```bash
"$HOME/Applications/Claude Router.app/Contents/MacOS/Claude Router" --status
```

Protokoll des Routers: `~/Library/Logs/Claude Router/router.log` (Link-Parameter werden nicht
protokolliert: In Anmeldeantworten stehen dort Codes).

## Wie es funktioniert

**Zweites Fenster.** `open -n -a Claude --args --user-data-dir=…/Claude-2` startet die App mit einem
eigenen Profilordner: eigene Anmeldung, eigene Cookies. Die Sperre „nur eine Instanz“ setzt die App
pro Profilordner, deshalb stört das zweite Fenster das erste nicht.

**Anmeldung.** Die Anmeldung über Google und SSO führt die App im Browser durch, die Antwort kommt als
`claude://`-Link zurück. Für macOS sind beide Fenster dieselbe App, deshalb erhält das Hauptfenster den
Link, und das zweite meldet sich nie an (im Protokoll des Hauptfensters steht
`Google sign-in code does not answer a sign-in this app started; ignoring`). Der Router ist der
Handler für `claude://`: Bei zwei offenen Fenstern fragt er, wohin, und übergibt den Link dem
gewählten Prozess als Ereignis „URL öffnen“ (GURL) an dessen PID. Solange Claude nicht der Handler
ist, kann sich die App laut ihrem eigenen Code über das Anmeldefenster von Apple anmelden, das die
Antwort direkt an ihr Fenster zurückgibt. Claude macht sich bei jedem Start wieder zum Handler für
`claude://` — der Router holt ihn sich alle 5 Sekunden zurück.

**Was die Fenster teilen:**

- Von selbst — `~/.claude` (die App ändert diesen Ordner nicht): CLAUDE.md, Skills, `settings.json`,
  Plugins von Claude Code, MCP-Server aus `~/.claude.json` und den `.mcp.json` der Projekte, Memory,
  Gesprächsdateien.
- Über `sync-profile.sh` vor jedem Start von „Claude 2“: Die Sitzungsliste ist ein Link auf den Ordner
  des Hauptfensters (Sitzungen liegen pro Konto, daher sieht jedes Fenster die Sitzungen seines
  Kontos), die Ordner der Erweiterungen sind Links; die MCP-Server der App (`mcpServers`), die
  Schalter der MCP-Werkzeuge und die Liste der Erweiterungen sind Kopien. Kopien statt Links: Die App
  schreibt einen Teil der Dateien über eine temporäre Datei und Umbenennen, ein Link auf eine Datei
  würde nach dem ersten Schreiben zur Kopie. Quelle ist das Hauptfenster: MCP-Server dort hinzufügen.
- Nicht verknüpfbar — was ein Konto auf dem Server speichert: Connectors (Gmail, Drive, Calendar), auf
  dem Konto aktivierte Plugins, Chats auf claude.ai.

## Wenn das zweite Fenster eine andere Anmeldung anbietet

Ein Profil kann in den Modus eines Drittanbieters wechseln: Anmeldung mit einem Token der Anthropic
Console, keine normale Anmeldung bei claude.ai, Protokolle in `~/Library/Logs/Claude-3p/`.
Erkennungszeichen: `"deploymentMode": "3p"` in
`~/Library/Application Support/Claude-2-3p/claude_desktop_config.json`. Schließen Sie das zweite
Fenster, setzen Sie dort `"1p"` und öffnen Sie das Fenster wieder über das Symbol „Claude 2“.

## Deinstallieren

```bash
pkill -x "Claude Router"; rm -rf "$HOME/Applications/Claude Router.app" "$HOME/Applications/Claude 2.app"
```

Beim nächsten Start wird Claude wieder zum Handler für `claude://`. Der Profilordner des zweiten
Fensters bleibt in `~/Library/Application Support/Claude-2`; sein Link auf die Sitzungen des
Hauptfensters ist `claude-code-sessions` (das Löschen des Links lässt die Sitzungen unberührt).

## Dateien

| Datei | Was sie tut |
|---|---|
| `main.swift`, `Info.plist`, `build.sh` | der Router, `~/Applications/Claude Router.app` |
| `claude2-launcher.applescript` | das Symbol „Claude 2“ |
| `sync-profile.sh` | übernimmt Sitzungen, MCP-Server und Erweiterungen des Hauptfensters ins zweite |
| `install.sh` | baut und installiert all das |

Das Auswahlfenster ohne Dialog testen: `defaults write local.claude.router testPick "Claude 2"` — der
nächste Link geht an „Claude 2“, danach wird die Einstellung zurückgesetzt.

## Lizenz

MIT
