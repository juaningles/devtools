<#
.SYNOPSIS
  Create a devtools overlay from templates\overlay, or refresh the boilerplate of an existing one.
  .\tools\new-overlay.ps1 -Name devtools-foo               # create ..\devtools-foo (next to devtools), git init, link it
  .\tools\new-overlay.ps1 -Name devtools-foo -Path D:\src   # create D:\src\devtools-foo
  .\tools\new-overlay.ps1 -Update ..\devtools-foo           # copy only the boilerplate files over an existing overlay
  Boilerplate = install.ps1, install.sh, .gitignore, .gitattributes, .devtools-overlay, ssh\README.md.
  -Update never touches README.md, shell\, bin-win\ or docs\. Review the diff in the overlay before committing.
#>
[CmdletBinding(DefaultParameterSetName = 'Create')]
param(
  [Parameter(ParameterSetName = 'Create', Mandatory)][string]$Name,
  [Parameter(ParameterSetName = 'Create')][string]$Path = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
  [Parameter(ParameterSetName = 'Update', Mandatory)][string]$Update
)
$ErrorActionPreference = 'Stop'
$Devtools = Split-Path -Parent $PSScriptRoot
$Template = Join-Path $Devtools 'templates\overlay'
$Boilerplate = @('install.ps1', 'install.sh', '.gitignore', '.gitattributes', '.devtools-overlay', 'ssh\README.md')

if ($PSCmdlet.ParameterSetName -eq 'Update') {
  $dest = (Resolve-Path $Update).Path
  if (-not (Test-Path (Join-Path $dest '.devtools-overlay')) -and -not (Test-Path (Join-Path $dest 'install.sh'))) {
    throw "$dest does not look like an overlay (no .devtools-overlay marker or install.sh)"
  }
  foreach ($f in $Boilerplate) {
    $to = Join-Path $dest $f
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
    Copy-Item (Join-Path $Template $f) $to -Force
    Write-Host "updated $to"
  }
  Write-Host "done. Review with: git -C `"$dest`" diff" -ForegroundColor Cyan
  return
}

if ($Name -notmatch '^[A-Za-z0-9._-]+$') { throw "overlay name must be a plain folder name: $Name" }
$dest = Join-Path (Resolve-Path $Path).Path $Name
if (Test-Path $dest) { throw "$dest already exists (use -Update to refresh its boilerplate)" }

Copy-Item $Template $dest -Recurse
Move-Item (Join-Path $dest 'shell\{{NAME}}.sh') (Join-Path $dest "shell\$Name.sh")
foreach ($f in @('README.md', "shell\$Name.sh")) {
  $p = Join-Path $dest $f
  [IO.File]::WriteAllText($p, ([IO.File]::ReadAllText($p) -replace '\{\{NAME\}\}', $Name))
}
Write-Host "created $dest" -ForegroundColor Green

git -C $dest init -q
git -C $dest add -A
if (git -C $dest config user.email) { git -C $dest commit -q -m "New devtools overlay from templates/overlay" }
else { Write-Warning 'git: no user.email configured; files are staged, commit them yourself' }
& (Join-Path $dest 'install.ps1') -Devtools $Devtools
Write-Host "`nnext: edit $dest\README.md and shell\$Name.sh, add a remote, push." -ForegroundColor Cyan
