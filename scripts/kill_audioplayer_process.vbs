Dim WinScriptHost
Set WinScriptHost = CreateObject("WScript.Shell")
WinScriptHost.Run "scripts\kill_audioplayer_process.bat",0
Set WinScriptHost = Nothing
