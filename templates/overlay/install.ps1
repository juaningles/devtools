<#
.SYNOPSIS
  Link this repo as a devtools overlay on Windows (junction devtools\overlays\<this folder name>),
  regenerate shims, and let WSL clones push back here. Boilerplate from devtools templates\overlay;
  refresh it with devtools\tools\new-overlay.ps1 -Update <this folder>.
  .\install.ps1                                   # devtools from DEVTOOLS_ROOT, else ..\devtools
  .\install.ps1 -Devtools D:\src\devtools
  .\install.ps1 -Wsl zdev,Ubuntu-24.04            # also clone into those distros and link there
#>
[CmdletBinding()]
param(
  [string]$Devtools = $(if ($env:DEVTOOLS_ROOT) { $env:DEVTOOLS_ROOT } else { Join-Path (Split-Path -Parent $PSScriptRoot) 'devtools' }),
  [string[]]$Wsl = @()
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Name = Split-Path -Leaf $Root
if (-not (Test-Path (Join-Path $Devtools 'install.ps1'))) { throw "devtools not found at $Devtools" }

git -C $Root config receive.denyCurrentBranch updateInstead
git -C $Root config pull.ff only
& (Join-Path $Devtools 'install.ps1') -SkipTools -NoDockerShim -Overlay $Root   # not -SkipPath: this overlay's bin-win must reach the user PATH

$src = '/mnt/' + $Root.Substring(0, 1).ToLower() + ($Root.Substring(2) -replace '\\', '/')
foreach ($d in $Wsl) {
  Write-Host "wsl[$d]: cloning $src -> ~/$Name and linking it as an overlay" -ForegroundColor Cyan
  wsl.exe -d $d -- bash -lc "bash '$src/install.sh' --from '$src'"
}
