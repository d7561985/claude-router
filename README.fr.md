# Claude Router

[English](README.md) · [Русский](README.ru.md) · [Deutsch](README.de.md) · Français

Deux fenêtres de l'application de bureau Claude pour macOS côte à côte, chacune connectée à son
propre compte. La connexion via Google et SSO fonctionne dans les deux, et les sessions, skills,
plugins et serveurs MCP sont partagés.

> Outil non officiel. Il repose sur le fonctionnement actuel de l'application Claude (l'option
> `--user-data-dir`, les dossiers de profil, les liens `claude://`) ; une mise à jour de l'application
> peut changer cela.

## Installation

Il faut macOS 13+, l'application Claude dans `/Applications` et les Command Line Tools
(`xcode-select --install`).

```bash
git clone https://github.com/d7561985/claude-router.git ~/projects/claude-router
```

```bash
~/projects/claude-router/install.sh
```

Cela crée `~/Applications/Claude Router.app` et l'icône `~/Applications/Claude 2.app` — vous pouvez
la glisser dans le Dock. Relancer `install.sh` met les deux à jour.

## Utilisation

1. La fenêtre principale est l'application Claude habituelle.
2. La deuxième fenêtre, c'est l'icône « Claude 2 ». Elle lance le routeur, reprend dans le profil de
   la deuxième fenêtre les sessions, serveurs MCP et extensions de la fenêtre principale, puis ouvre
   la deuxième fenêtre.
3. Quand les deux fenêtres sont ouvertes et qu'un lien `claude://` arrive (par exemple la réponse
   d'une connexion via Google ou SSO), le routeur demande quelle fenêtre doit l'ouvrir. Pour vous
   connecter dans la deuxième fenêtre, choisissez « Claude 2 ».

Une seule règle : **un compte dans une seule fenêtre à la fois.** L'application n'empêche pas deux
fenêtres de travailler sur la même session. Si les deux fenêtres ont été connectées en dernier au même
compte, l'icône « Claude 2 » vous prévient.

Après un redémarrage, rien à lancer à la main : l'icône « Claude 2 » lance le routeur elle-même. Tant
que seule la fenêtre principale est ouverte, Claude traite lui-même les liens `claude://`.

Vérifier quelle application reçoit les liens et quelles fenêtres sont ouvertes :

```bash
"$HOME/Applications/Claude Router.app/Contents/MacOS/Claude Router" --status
```

Journal du routeur : `~/Library/Logs/Claude Router/router.log` (les paramètres des liens n'y sont pas
écrits : les réponses de connexion contiennent des codes).

## Comment ça marche

**Deuxième fenêtre.** `open -n -a Claude --args --user-data-dir=…/Claude-2` lance l'application avec
son propre dossier de profil : sa propre connexion et ses propres cookies. Le verrou « une seule
instance » de l'application porte sur le dossier de profil, donc la deuxième fenêtre ne gêne pas la
première.

**Connexion.** L'application mène la connexion Google et SSO dans le navigateur et reçoit la réponse
sous forme de lien `claude://`. Pour macOS, les deux fenêtres sont la même application : le lien part
donc vers la fenêtre principale et la deuxième ne se connecte jamais (le journal de la fenêtre
principale indique `Google sign-in code does not answer a sign-in this app started; ignoring`). Le
routeur est le gestionnaire de `claude://` : avec deux fenêtres ouvertes, il demande où envoyer le
lien et le transmet au processus choisi sous forme d'événement « ouvrir l'URL » (GURL) adressé à son
pid. Tant que Claude n'est pas le gestionnaire, son propre code peut passer par la feuille de
connexion d'Apple, qui renvoie la réponse directement dans sa fenêtre. Claude se redéclare
gestionnaire de `claude://` à chaque démarrage ; le routeur reprend la main toutes les 5 secondes.

**Ce que les fenêtres partagent :**

- D'office — `~/.claude` (l'application ne modifie pas ce dossier) : CLAUDE.md, skills,
  `settings.json`, plugins de Claude Code, serveurs MCP de `~/.claude.json` et des `.mcp.json` des
  projets, mémoire, fichiers de conversation.
- Via `sync-profile.sh`, avant chaque lancement de « Claude 2 » : la liste des sessions est un lien
  vers le dossier de la fenêtre principale (les sessions sont rangées par compte, chaque fenêtre voit
  donc celles de son compte), les dossiers d'extensions sont des liens ; les serveurs MCP de
  l'application (`mcpServers`), les interrupteurs des outils MCP et la liste des extensions sont des
  copies. Des copies et non des liens : l'application écrit certains fichiers via un fichier
  temporaire puis un renommage, et un lien vers un fichier deviendrait une copie après la première
  écriture. La source est la fenêtre principale : ajoutez-y les serveurs MCP.
- Impossible à lier — ce que le compte garde sur le serveur : connecteurs (Gmail, Drive, Calendar),
  plugins activés sur le compte, conversations claude.ai.

## Si la deuxième fenêtre propose une autre connexion

Un profil peut passer en mode fournisseur tiers : connexion avec un jeton Anthropic Console, pas de
connexion claude.ai habituelle, journaux écrits dans `~/Library/Logs/Claude-3p/`. Le signe :
`"deploymentMode": "3p"` dans `~/Library/Application Support/Claude-2-3p/claude_desktop_config.json`.
Fermez la deuxième fenêtre, mettez-y `"1p"` et rouvrez la fenêtre avec l'icône « Claude 2 ».

## Désinstallation

```bash
pkill -x "Claude Router"; rm -rf "$HOME/Applications/Claude Router.app" "$HOME/Applications/Claude 2.app"
```

Claude redevient le gestionnaire de `claude://` à son prochain démarrage. Le dossier de profil de la
deuxième fenêtre reste dans `~/Library/Application Support/Claude-2` ; son lien vers les sessions de
la fenêtre principale est `claude-code-sessions` (supprimer le lien ne touche pas aux sessions).

## Fichiers

| Fichier | Rôle |
|---|---|
| `main.swift`, `Info.plist`, `build.sh` | le routeur, `~/Applications/Claude Router.app` |
| `claude2-launcher.applescript` | l'icône « Claude 2 » |
| `sync-profile.sh` | reprend dans la deuxième fenêtre les sessions, serveurs MCP et extensions de la fenêtre principale |
| `install.sh` | compile et installe le tout |

Tester la fenêtre de choix sans boîte de dialogue : `defaults write local.claude.router testPick "Claude 2"`
— le lien suivant part vers « Claude 2 », puis le réglage est effacé.

## Licence

MIT
