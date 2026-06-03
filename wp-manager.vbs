Set WshShell = CreateObject("WScript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(Wscript.ScriptFullName)
WshShell.CurrentDirectory = strPath
WshShell.Run "cmd.exe /c start.bat", 0, False
