@echo off
REM docker2wsl.cmd / podman2wsl.cmd - compatibility names for the old bin scripts.
REM Both forward to container2wsl.bat (C:\code\docker2wsl), the tested replacement.
REM Note the argument style changed: image is positional and options are --name/--user/--location
REM instead of /image /distro /user /storage. Set CONTAINER2WSL to override the location.
setlocal
if not defined CONTAINER2WSL set "CONTAINER2WSL=C:\code\docker2wsl\container2wsl.bat"
if not exist "%CONTAINER2WSL%" (
  echo container2wsl.bat not found at "%CONTAINER2WSL%". Clone/locate the docker2wsl project or set CONTAINER2WSL.
  exit /b 2
)
if "%~1"=="" (
  echo %~n0 now forwards to container2wsl.bat. New syntax:
  echo   %~n0 ^<image^> [--name NAME] [--user USER] [--location DIR] [-b bootstrap]... [--dry-run]
  echo.
  call "%CONTAINER2WSL%" --help
  exit /b 1
)
call "%CONTAINER2WSL%" %*
exit /b %ERRORLEVEL%
