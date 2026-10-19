# shell/profile.ps1 - dot-sourced from $PROFILE (install.ps1 adds the line).
# PATH is NOT set here: on Windows install.ps1 writes it once to the user
# environment, so cmd.exe, PowerShell and Git Bash all see the same PATH.

$env:DEVTOOLS_ROOT = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Functions generated from shell/aliases.sh (#win lines). Rebuild with install.cmd.
$gen = Join-Path $PSScriptRoot 'aliases.generated.ps1'
if (Test-Path $gen) { . $gen } else { Write-Host "devtools: run install.cmd to generate aliases" -ForegroundColor Yellow }

function devtools-sync  { & (Join-Path $env:DEVTOOLS_ROOT 'sync.ps1') @args }
function devtools-shims { & (Join-Path $env:DEVTOOLS_ROOT 'tools\gen-shims.ps1') }

# uv per-OS venv, mirrors activate() in aliases.sh
function activate {
  $venv = ".venv\Windows"
  if (Test-Path pyproject.toml) { $env:UV_PROJECT_ENVIRONMENT = $venv; uv sync }
  else { uv venv $venv; if (Test-Path requirements.txt) { $env:VIRTUAL_ENV = (Resolve-Path $venv).Path; uv pip install -r requirements.txt } }
  . "$venv\Scripts\Activate.ps1"
}

# overlay (private aliases etc., docs/OVERLAY.md): dot-source its shell\*.ps1
if (-not $env:DEVTOOLS_OVERLAY) { $env:DEVTOOLS_OVERLAY = Join-Path $env:DEVTOOLS_ROOT 'overlay' }
if (Test-Path (Join-Path $env:DEVTOOLS_OVERLAY 'shell')) {
  Get-ChildItem (Join-Path $env:DEVTOOLS_OVERLAY 'shell') -Filter *.ps1 | Sort-Object Name | ForEach-Object { . $_.FullName }
}
