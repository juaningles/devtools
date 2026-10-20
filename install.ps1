<#
.SYNOPSIS
  Set up devtools on Windows: tools via winget, user PATH, PowerShell profile,
  Git Bash ~/.bashrc, cmd shims, and (optionally) the WSL clones.

.EXAMPLE
  .\install.ps1                       # everything except WSL
  .\install.ps1 -Wsl Ubuntu-24.04,devnode
  .\install.ps1 -SkipTools            # just PATH/profile/shims
  .\install.ps1 -SkipTools -Overlay ..\my-overlay,..\work-overlay   # link overlays (docs/OVERLAY.md)
#>
[CmdletBinding()]
param(
  [switch]$SkipTools,
  [switch]$SkipPath,
  [switch]$NoDockerShim,
  [string[]]$Wsl = @(),
  [string[]]$Overlay = @()
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Write-Host "devtools root: $Root" -ForegroundColor Cyan

# ---------------------------------------------------------------- docker.exe = podman.exe
# VS Code's Dev Containers extension spawns `docker` as a direct child process and cannot
# use a .bat shim, so a real docker.exe is needed. Podman answers to the docker CLI when
# invoked under that name. The copy is gitignored (*.exe) and refreshed on each run.
if (-not $NoDockerShim) {
  $podman = Get-Command podman.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
  $realDocker = Get-Command docker.exe -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch '\\code\\(bin|devtools)\\' } | Select-Object -First 1
  if ($podman -and -not $realDocker) {
    Copy-Item $podman (Join-Path $Root 'bin-win\docker.exe') -Force
    Write-Host "docker shim: bin-win\docker.exe <- $podman" -ForegroundColor Green
  } elseif ($realDocker) { Write-Host "docker shim: skipped, real docker.exe at $($realDocker.Source)" }
  else { Write-Host 'docker shim: skipped, podman not installed yet (re-run after tools install)' }
}

# ---------------------------------------------------------------- tools (winget)
if (-not $SkipTools) {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'winget not found; install App Installer from the Microsoft Store' }
  $manifest = Get-Content (Join-Path $Root 'tools.json') -Raw | ConvertFrom-Json
  foreach ($t in $manifest.tools) {
    $installed = (winget list --id $t.winget --exact --accept-source-agreements --disable-interactivity 2>$null) -match [regex]::Escape($t.winget)
    if ($installed -and -not $t.pin) { Write-Host ("  ok       {0,-10} {1}" -f $t.name, $t.winget); continue }
    if ($installed -and $t.pin -and ($installed -join ' ') -match "\s$([regex]::Escape($t.pin))\s") { Write-Host ("  ok       {0,-10} {1} (pinned {2})" -f $t.name, $t.winget, $t.pin); continue }
    $argv = @('install', '--id', $t.winget, '--exact', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
    if ($t.pin)   { $argv += @('--version', $t.pin) }
    if ($t.scope) { $argv += @('--scope', $t.scope) }
    Write-Host ("  install  {0,-10} {1} {2}" -f $t.name, $t.winget, $(if ($t.pin) { "== $($t.pin)" } else { '' }))
    & winget @argv | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0 -and $t.scope) {   # some packages reject --scope; retry without
      & winget ($argv | Where-Object { $_ -notin @('--scope', $t.scope) }) | Select-Object -Last 1
    }
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget failed for $($t.winget) (exit $LASTEXITCODE)" }
  }
  if (Get-Command uv -ErrorAction SilentlyContinue) { uv tool update-shell 2>$null | Out-Null }
}

# ---------------------------------------------------------------- overlays (junctions, no admin needed)
# One junction per repo at overlays\<name>, loaded in name order. The pre-2026-10-20 single
# `overlay` junction is moved into overlays\ on the first run.
$overlaysDir = Join-Path $Root 'overlays'
New-Item -ItemType Directory -Force -Path $overlaysDir | Out-Null
$oldLink = Get-Item (Join-Path $Root 'overlay') -Force -ErrorAction SilentlyContinue
if ($oldLink -and ($oldLink.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  $oldTarget = $oldLink.Target | Select-Object -First 1
  if ($oldTarget) { $Overlay = @($oldTarget) + @($Overlay | Where-Object { $_ }) }
  cmd /c rmdir "$($oldLink.FullName)" | Out-Null   # the junction only, never the target
  Write-Host "overlay: moved the single 'overlay' link into overlays\" -ForegroundColor Yellow
}
foreach ($ov in @($Overlay | Where-Object { $_ })) {
  $target = (Resolve-Path $ov).Path
  $link = Join-Path $overlaysDir (Split-Path -Leaf $target)
  $item = Get-Item $link -Force -ErrorAction SilentlyContinue
  if ($item -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    Write-Warning "overlay: $link exists and is not a link; leaving it alone"
  } else {
    if ($item) { cmd /c rmdir "$link" | Out-Null }
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Host "overlay: $link -> $target" -ForegroundColor Green
  }
}
$overlayBinWin = @(Get-ChildItem $overlaysDir -Directory | Sort-Object Name | ForEach-Object { Join-Path $_.FullName 'bin-win' } | Where-Object { Test-Path $_ })

# ---------------------------------------------------------------- shims
& (Join-Path $Root 'tools\gen-shims.ps1') -Root $Root

# ---------------------------------------------------------------- user PATH
if (-not $SkipPath) {
  $want = @("$Root\bin-win", "$Root\bin-win\gen", "$Root\bin")   # bin = bash scripts, reachable from Git Bash
  # later overlays win, so they go first: reverse the name order
  if ($overlayBinWin) { [array]::Reverse($overlayBinWin); $want = @($overlayBinWin) + $want }
  $cur  = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ }
  $stale = @($cur | Where-Object { $_ -like "$Root\overlay\*" })   # pre-overlays\ single-link entries
  if ($stale) { $cur = @($cur | Where-Object { $_ -notin $stale }); Write-Host "PATH (user): dropped stale $($stale -join ', ')" -ForegroundColor Yellow }
  $new  = @($want | Where-Object { $_ -notin $cur }) + $cur
  if ($new.Count -ne $cur.Count -or $stale) {
    [Environment]::SetEnvironmentVariable('Path', ($new -join ';'), 'User')
    Write-Host "PATH (user): prepended $($want -join ', ')" -ForegroundColor Green
  } else { Write-Host 'PATH (user): already set' }
  if ($cur -contains 'C:\code\bin') { Write-Warning 'C:\code\bin is still on PATH and shadows devtools until you remove it' }
}

# ---------------------------------------------------------------- PowerShell profile
$prof = $PROFILE.CurrentUserAllHosts
$line = ". '$Root\shell\profile.ps1'"
if (-not (Test-Path $prof)) { New-Item -ItemType File -Force -Path $prof | Out-Null }
if (-not (Select-String -Path $prof -SimpleMatch $line -Quiet)) { Add-Content $prof "`n# devtools`n$line"; Write-Host "profile: added to $prof" -ForegroundColor Green } else { Write-Host 'profile: already set' }

# ---------------------------------------------------------------- Git Bash ~/.bashrc
$bashrc = Join-Path $HOME '.bashrc'
$posix  = '/' + $Root.Substring(0, 1).ToLower() + ($Root.Substring(2) -replace '\\', '/')   # C:\code\x -> /c/code/x (no scriptblock -replace: PS 5.1)
$bline  = ". `"$posix/bashrc`""
if (-not (Test-Path $bashrc) -or -not (Select-String -Path $bashrc -SimpleMatch $bline -Quiet)) {
  Add-Content $bashrc "`n# devtools`n$bline"; Write-Host "git bash: added to $bashrc" -ForegroundColor Green
} else { Write-Host 'git bash: already set' }

# ---------------------------------------------------------------- git: let WSL clones push back here
if (Test-Path (Join-Path $Root '.git')) {
  git -C $Root config receive.denyCurrentBranch updateInstead
  git -C $Root config pull.ff only
}

# ---------------------------------------------------------------- WSL clones
foreach ($d in $Wsl) {
  $src = "/mnt/" + $posix.TrimStart('/')
  Write-Host "wsl[$d]: cloning $src -> ~/devtools and running install.sh" -ForegroundColor Cyan
  wsl.exe -d $d -- bash -lc "if [ -d ~/devtools/.git ]; then git -C ~/devtools pull --ff-only; else git clone '$src' ~/devtools; fi && ~/devtools/install.sh"
}

Write-Host "`ndone. Open a new terminal. Private aliases go in an overlay: see docs\OVERLAY.md." -ForegroundColor Cyan
