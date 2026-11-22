use AppleScript version "2.4"
use framework "AppKit"
use scripting additions

-- "Claude 2": a second Claude window with its own profile folder + the claude:// link router
set profileName to "Claude-2"
set homeDir to POSIX path of (path to home folder)
set dataDir to homeDir & "Library/Application Support/" & profileName
set routerApp to homeDir & "Applications/Claude Router.app"
set syncScript to "__SYNC_SCRIPT__" -- install.sh puts the path to sync-profile.sh here

-- the router takes claude:// links and hands them to the right window
do shell script "open -g " & quoted form of routerApp

set pidText to do shell script "pgrep -o -f " & quoted form of ("^/Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=" & dataDir & "$") & " || true"
if pidText is "" then
	-- the window is closed: bring in the main window's sessions, MCP servers and extensions
	set syncOut to do shell script "/bin/zsh " & quoted form of syncScript & " " & quoted form of profileName
	if syncOut contains "same-account" then
		set t to sameAccountTexts()
		display dialog (item 1 of t) buttons {item 2 of t, item 3 of t} default button (item 2 of t) cancel button (item 2 of t) with title "Claude 2" with icon caution
	end if
	do shell script "open -n -a Claude --args " & quoted form of ("--user-data-dir=" & dataDir)
else
	set runningApp to current application's NSRunningApplication's runningApplicationWithProcessIdentifier:(pidText as integer)
	if runningApp is not missing value then runningApp's activateWithOptions:(current application's NSApplicationActivateAllWindows)
end if

-- warning {text, cancel button, open button} in the system language: the first of en, ru, de, fr
on sameAccountTexts()
	repeat with lang in ((current application's NSLocale's preferredLanguages()) as list)
		set lang to lang as text
		if lang starts with "ru" then return {"В основном окне и в «Claude 2» последним входил один и тот же аккаунт. Если оба окна будут в одном аккаунте, они начнут писать в одни и те же сессии.", "Отмена", "Открыть всё равно"}
		if lang starts with "de" then return {"Im Hauptfenster und in „Claude 2“ war zuletzt dasselbe Konto angemeldet. Nutzen beide Fenster dasselbe Konto, schreiben sie in dieselben Sitzungen.", "Abbrechen", "Trotzdem öffnen"}
		if lang starts with "fr" then return {"La fenêtre principale et « Claude 2 » ont été connectées en dernier au même compte. Si les deux fenêtres utilisent le même compte, elles écriront dans les mêmes sessions.", "Annuler", "Ouvrir quand même"}
		if lang starts with "en" then exit repeat
	end repeat
	return {"The main window and “Claude 2” were last signed in to the same account. If both windows use one account, they will write to the same sessions.", "Cancel", "Open anyway"}
end sameAccountTexts
