@echo off
REM install.cmd - (re)generate the cmd.exe shims and PowerShell functions from shell\aliases.sh.
REM Put %~dp0bin-win and %~dp0bin-win\gen on PATH (install.ps1 does this) and the
REM aliases in aliases.sh marked #win become commands in plain cmd.exe.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\gen-shims.ps1" %*
exit /b %ERRORLEVEL%
