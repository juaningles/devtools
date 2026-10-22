@echo off
REM rebuild-wsl.bat - build a WSL distro with container2wsl from a recipe kept in a devtools overlay.
REM   rebuild-wsl                          list the recipes found in devtools\overlays\*\recipes\*.conf
REM   rebuild-wsl NAME [args...]           build recipes\NAME.conf; args go to container2wsl after the
REM                                        recipe's defaults, so -n/-u/--force/--dry-run override, -b/-p add
REM   rebuild-wsl PATH\to\x.conf [args]    use that file (anything with a \ or / or ending in .conf)
REM Recipe: key=value lines (no spaces around =), # comments on their own line. Keys: image (required),
REM name (default: recipe file name), user, location, bootstraps, poststraps (space separated), extra (raw),
REM target (wsl or container: --target), commit (image:tag: --commit, container target only).
REM engine and arch are for the macOS/Linux runner (devtools bin/rebuild-container) and ignored here.
REM Build the same recipe as a container instead: rebuild-wsl NAME --target container
REM Same recipe name in several overlays: the last in name order wins, like overlay aliases.
REM container2wsl is found via CONTAINER2WSL, then PATH, then the docker2wsl clone next to devtools.
REM Run from an elevated cmd or PowerShell.
setlocal EnableDelayedExpansion
set "DEVTOOLS=%~dp0.."
set "RECIPE=%~1"
if "%RECIPE%"=="" goto :list
if /i "%RECIPE%"=="--list" goto :list
if /i "%RECIPE%"=="-h" goto :help
if /i "%RECIPE%"=="--help" goto :help

:: --- resolve the recipe file: a path as given, else overlays\*\recipes\NAME.conf (last overlay wins) ---
set "FILE="
set "RECIPE_NAME=%~n1"
echo "%RECIPE%" | findstr /r /c:"[\\/]" /c:"\.conf" >nul 2>&1
if not errorlevel 1 set "FILE=%~f1"
if defined FILE if not exist "%FILE%" (echo rebuild-wsl: recipe file not found: %FILE% 1>&2 & exit /b 2)
if not defined FILE for /d %%o in ("%DEVTOOLS%\overlays\*") do if exist "%%~fo\recipes\%RECIPE%.conf" set "FILE=%%~fo\recipes\%RECIPE%.conf"
if not defined FILE (
    echo rebuild-wsl: no recipe "%RECIPE%" in %DEVTOOLS%\overlays\*\recipes\ 1>&2
    call :list
    exit /b 2
)

:: --- read the recipe ---
set "R_image=" & set "R_name=" & set "R_user=" & set "R_location=" & set "R_bootstraps=" & set "R_poststraps=" & set "R_extra="
set "R_target=" & set "R_commit=" & set "R_engine=" & set "R_arch="
for /f "usebackq eol=# tokens=1,* delims==" %%k in ("%FILE%") do set "R_%%k=%%l"
if not defined R_image (echo rebuild-wsl: %FILE% has no image= line 1>&2 & exit /b 2)
if not defined R_name set "R_name=%RECIPE_NAME%"

:: --- defaults from the recipe, then every remaining command line argument (last one wins) ---
set "ARGS=%R_image% -n %R_name%"
if defined R_user set "ARGS=!ARGS! -u %R_user%"
if defined R_location set "ARGS=!ARGS! -l "%R_location%""
if defined R_bootstraps for %%b in (%R_bootstraps%) do set "ARGS=!ARGS! -b %%b"
if defined R_poststraps for %%p in (%R_poststraps%) do set "ARGS=!ARGS! -p %%p"
if defined R_target set "ARGS=!ARGS! --target %R_target%"
if defined R_extra set "ARGS=!ARGS! %R_extra%"
set "REST="
:rest
shift
if "%~1"=="" goto :run
set "REST=!REST! %1"
goto :rest

:run
:: commit= applies only when this build is a container (recipe target=, or --target container given)
if defined R_commit (
    set "_CT=0"
    if /i "%R_target%"=="container" set "_CT=1"
    echo "!REST!" | findstr /i /c:"--target container" >nul && set "_CT=1"
    echo "!REST!" | findstr /i /c:"--target wsl" >nul && set "_CT=0"
    if "!_CT!"=="1" set "ARGS=!ARGS! --commit %R_commit%"
)
call :find_c2w || exit /b 2
echo rebuild-wsl: recipe %FILE%
echo rebuild-wsl: container2wsl !ARGS!!REST!
call "%CONTAINER2WSL%" !ARGS!!REST!
exit /b %ERRORLEVEL%

:find_c2w
if not defined CONTAINER2WSL for %%f in (container2wsl.bat) do set "CONTAINER2WSL=%%~$PATH:f"
if not defined CONTAINER2WSL if exist "%DEVTOOLS%\..\docker2wsl\container2wsl.bat" set "CONTAINER2WSL=%DEVTOOLS%\..\docker2wsl\container2wsl.bat"
if not defined CONTAINER2WSL (echo container2wsl.bat not found: set CONTAINER2WSL, put it on PATH, or clone docker2wsl next to devtools 1>&2 & exit /b 2)
exit /b 0

:list
echo Recipes in %DEVTOOLS%\overlays\*\recipes\ (name, overlay, image):
for /d %%o in ("%DEVTOOLS%\overlays\*") do for %%r in ("%%~fo\recipes\*.conf") do (
    set "IMG="
    for /f "usebackq eol=# tokens=1,* delims==" %%k in ("%%~fr") do if "%%k"=="image" set "IMG=%%l"
    echo   %%~nr  ^(%%~no^)  !IMG!
)
exit /b 0

:help
findstr /b /c:"REM " "%~f0"
exit /b 0
