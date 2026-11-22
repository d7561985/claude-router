use AppleScript version "2.4"
use framework "AppKit"
use scripting additions

-- «Claude 2»: второе окно Claude со своей папкой профиля + роутер ссылок claude://
set profileName to "Claude-2"
set homeDir to POSIX path of (path to home folder)
set dataDir to homeDir & "Library/Application Support/" & profileName
set routerApp to homeDir & "Applications/Claude Router.app"
set syncScript to "__SYNC_SCRIPT__" -- install.sh подставляет путь к sync-profile.sh

-- роутер: забирает ссылки claude:// и отдаёт их нужному окну
do shell script "open -g " & quoted form of routerApp

set pidText to do shell script "pgrep -o -f " & quoted form of ("^/Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=" & dataDir & "$") & " || true"
if pidText is "" then
	-- окно закрыто: подтянуть сессии, MCP и расширения основного окна
	set syncOut to do shell script "/bin/zsh " & quoted form of syncScript & " " & quoted form of profileName
	if syncOut contains "same-account" then
		display dialog "В основном окне и в «Claude 2» последним входил один и тот же аккаунт. Если оба окна будут в одном аккаунте, они начнут писать в одни и те же сессии." buttons {"Отмена", "Открыть всё равно"} default button "Отмена" cancel button "Отмена" with title "Claude 2" with icon caution
	end if
	do shell script "open -n -a Claude --args " & quoted form of ("--user-data-dir=" & dataDir)
else
	set runningApp to current application's NSRunningApplication's runningApplicationWithProcessIdentifier:(pidText as integer)
	if runningApp is not missing value then runningApp's activateWithOptions:(current application's NSApplicationActivateAllWindows)
end if
