<#
.SYNOPSIS
  k8stool - find AKS clusters across subscriptions and (with --install) fetch
  kubeconfig credentials for each, reporting PASS/FAIL per step.
  PowerShell port of bin/k8stool; accepts the same bash-style flags.

  k8stool --query 'myorg-.*-dev'                dry run: print the steps
  k8stool --query dev --name eastus --install   run them for matching clusters
  k8stool <sub-id> [<sub-id> ...] --install
#>
$ErrorActionPreference = 'Continue'
$Install = $false; $Query = ''; $NamePat = ''; $Subs = @()

function Show-Usage {
  @"
Usage: k8stool [options] [sub-id ...]
Options:
  --install          run the steps (default is a dry run that prints them)
  --query PATTERN    add subscriptions whose name matches PATTERN (regex)
  --name PATTERN     only clusters whose name matches PATTERN (regex)
  --help
Requires: az, kubectl, kubelogin
"@
}

for ($i = 0; $i -lt $args.Count; $i++) {
  switch -Regex ($args[$i]) {
    '^(--install|-Install)$' { $Install = $true }
    '^(--help|-h|-\?)$'      { Show-Usage; exit 0 }
    '^(--query|-Query)$'     { $i++; if ($i -ge $args.Count) { Write-Error '--query needs a pattern'; exit 2 }; $Query = $args[$i] }
    '^(--name|-Name)$'       { $i++; if ($i -ge $args.Count) { Write-Error '--name needs a pattern'; exit 2 }; $NamePat = $args[$i] }
    '^-'                     { Write-Error "Unknown option: $($args[$i])"; Show-Usage; exit 1 }
    default                  { $Subs += $args[$i] }
  }
}

foreach ($t in 'az', 'kubectl', 'kubelogin') { if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { Write-Error "$t not found"; exit 1 } }

if ($Query) {
  $Subs += (az account list -o json | ConvertFrom-Json) | Where-Object { $_.name -match $Query } | ForEach-Object id
}
if (-not $Subs) { Write-Error 'no subscriptions given or matched'; Show-Usage; exit 1 }

$E = [char]27; $GREEN = "$E[0;32m"; $RED = "$E[0;31m"; $BLUE = "$E[0;34m"; $RESET = "$E[0m"

function Banner($t) {
  "$BLUE#========================================================================$RESET"
  "$BLUE# $t$RESET"
  "$BLUE#========================================================================$RESET"
}

# Run-Test "exe arg arg": dry-run prints it; otherwise runs it and checks the real exit code
function Run-Test([string]$cmdline) {
  if (-not $Install) { $cmdline; return }
  $parts = $cmdline -split ' +'
  $out = & $parts[0] $parts[1..($parts.Count - 1)] 2>&1
  if ($LASTEXITCODE -eq 0) { "${GREEN}PASS${RESET}`t$cmdline" } else { "${RED}FAIL${RESET}`t$cmdline" }
  if ($out) { $out | ForEach-Object { "$_" } }
}

foreach ($sub in $Subs) {
  $clusters = az aks list --subscription $sub -o json | ConvertFrom-Json
  foreach ($c in $clusters | Where-Object { -not $NamePat -or $_.name -match $NamePat }) {
    $subId = if ($c.id -match '/subscriptions/([^/]+)/') { $Matches[1] } else { $sub }
    Banner $c.name
    if ($c.fqdn) { Run-Test "nslookup $($c.fqdn)" }
    if ($c.privateFqdn) { Run-Test "nslookup $($c.privateFqdn)" } else { "${BLUE}SKIPPED${RESET}`tprivate fqdn not set" }
    Run-Test "az account set --subscription $subId"
    Run-Test "az aks get-credentials --resource-group $($c.resourceGroup) --name $($c.name) --overwrite-existing"
    Run-Test "kubelogin convert-kubeconfig -l azurecli"
    Run-Test "kubectl get nodes"
    ''
  }
}
