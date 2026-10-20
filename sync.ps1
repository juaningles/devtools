<#
.SYNOPSIS
  Sync the Windows clone (the hub) and every WSL clone, then rebuild cmd shims.
  .\sync.ps1                 pull here (if a remote exists), then every WSL distro that has ~/devtools
  .\sync.ps1 -Wsl devnode    only the named distros
#>
[CmdletBinding()]
param([string[]]$Wsl)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$env:WSL_UTF8 = '1'

if (git -C $Root status --porcelain) { Write-Warning "uncommitted changes in $Root - commit them first so WSL clones can pull them"; git -C $Root status --short }
if (git -C $Root remote) { git -C $Root pull --ff-only } else { Write-Host 'sync: no remote on the Windows clone; it is the origin for WSL' }
$overlays = @(Get-ChildItem (Join-Path $Root 'overlays') -Directory -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object FullName)
if (Test-Path (Join-Path $Root 'overlay')) { $overlays += (Join-Path $Root 'overlay') }
foreach ($overlay in $overlays) {
  if (-not (Test-Path (Join-Path $overlay '.git'))) { continue }
  if (git -C $overlay status --porcelain) { Write-Warning "uncommitted changes in overlay $overlay" }
  if (git -C $overlay remote) { git -C $overlay pull --ff-only } else { Write-Host "sync: overlay $(Split-Path -Leaf $overlay) has no remote" }
}

if (-not $Wsl) { $Wsl = (wsl.exe --list --quiet) | Where-Object { $_ -and $_ -notmatch '^(docker-desktop|podman-machine|rancher)' } }
foreach ($d in $Wsl) {
  $out = wsl.exe -d $d -- bash -lc 'test -x ~/devtools/sync.sh && ~/devtools/sync.sh || echo "no clone"' 2>&1
  Write-Host ("wsl[{0}]: {1}" -f $d, (($out | Select-Object -Last 1) -join ' '))
}

& (Join-Path $Root 'tools\gen-shims.ps1') -Root $Root
