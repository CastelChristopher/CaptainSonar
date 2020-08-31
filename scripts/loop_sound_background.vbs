Dim WinScriptHost, audioPlayer, scaleFactorArg, loopArg, fileArg
Set WinScriptHost = CreateObject("WScript.Shell")
' Wscript.Echo WScript.Arguments(0) & " " & WScript.Arguments(1)
audioPlayer     = "bin\audio_player\mpg123.exe "
scaleFactorArg  = "--scale " & WScript.Arguments(0) & " "
loopArg         = "--loop -1 "
fileArg         = Chr(34) & WScript.Arguments(1) & Chr(34)
WinScriptHost.Run audioPlayer & scaleFactorArg & loopArg & fileArg, 0
Set WinScriptHost = Nothing
