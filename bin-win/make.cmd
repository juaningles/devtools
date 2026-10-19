@echo off
REM make.cmd - run GNU Make on Windows with a POSIX sh available to it.
REM
REM Nearly every Makefile under C:\code uses sh recipes (rm -rf, $$VAR, if [ ]). GNU Make
REM only uses sh if sh.exe is on PATH, otherwise it falls back to cmd.exe and those recipes
REM break. Putting Git's usr\bin on the global PATH would shadow Windows find/sort/etc, so
REM this wrapper adds it for the make process only, then runs the real make.exe.
REM Prefers the winget install (ezwinports 4.4.1; enable "make" in tools.json) over any
REM stray make.exe elsewhere on PATH, such as the old GnuWin32 3.81 in C:\code\bin.
setlocal
set "PATH=%ProgramFiles%\Git\usr\bin;%PATH%"
set "MAKE_EXE="
REM 1) winget portable package (ezwinports ships as a zip: no Links shim, lives under Packages)
for /d %%d in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\ezwinports.make_*") do if exist "%%~d\bin\make.exe" set "MAKE_EXE=%%~d\bin\make.exe"
REM 2) winget Links shim, if a future package provides one
if not defined MAKE_EXE if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\make.exe" set "MAKE_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Links\make.exe"
REM 3) anything else on PATH
if not defined MAKE_EXE for /f "delims=" %%m in ('where make.exe 2^>nul') do if not defined MAKE_EXE set "MAKE_EXE=%%m"
if not defined MAKE_EXE (
  echo make.exe not found. Enable "make" in tools.json and run install.ps1, or: winget install --id ezwinports.make --exact --version 4.4.1
  exit /b 9009
)
"%MAKE_EXE%" %*
exit /b %ERRORLEVEL%
