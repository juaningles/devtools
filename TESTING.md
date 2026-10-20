# Testing devtools

There is no test runner; the repo is shell glue, so the tests are commands you run on each platform and compare against the expected result. Sections are ordered from "no side effects" to "touches your machine". Run the static checks after every edit and the smoke tests after `install`.

## 1. Static checks (any platform, no side effects)

From Git Bash or WSL, in the clone:

```bash
# bash syntax of everything that is sourced or executed
for f in bashrc shell/*.sh bin/cron2cli bin/cron2job bin/k8stool bin/cron-keepalive bin/fixpod.sh bin/csv2json bin/venv.sh install.sh sync.sh shell/completions/*; do
  bash -n "$f" && echo "ok   $f" || echo "FAIL $f"
done
# zsh syntax of what zsh sources (WSL/Linux with zsh installed)
for f in shell/zshrc shell/env.sh shell/aliases.sh; do zsh -n "$f" && echo "ok   zsh $f" || echo "FAIL zsh $f"; done

# line endings: bash files must be LF, .cmd/.bat must be CRLF (see .gitattributes)
file bashrc shell/*.sh shell/zshrc bin/* install.sh sync.sh | grep -i crlf && echo "FAIL: CRLF in a bash file"
file bin-win/*.cmd bin-win/*.bat install.cmd | grep -vi crlf && echo "FAIL: LF in a cmd file"

# executable bits recorded in git (WSL clones depend on this)
git ls-files -s bin install.sh sync.sh | grep -v '^100755' | grep -v '\.ps1'   # expect no output

# nothing secret or generated is tracked
git ls-files | grep -E '^overlay|private\.(sh|ps1)$|bin-win/gen/|generated|\.exe$|\.dll$'    # expect no output
```

From PowerShell:

```powershell
# parse every .ps1
foreach ($f in 'install.ps1','sync.ps1','tools\gen-shims.ps1','shell\profile.ps1','bin\k8stool.ps1') {
  $e = $null; [void][Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$null, [ref]$e)
  if ($e) { "FAIL $f : $($e.Message)" } else { "ok   $f" }
}
# tools.json is valid and every id resolves
$m = Get-Content tools.json -Raw | ConvertFrom-Json
foreach ($t in $m.tools) { $r = winget search --id $t.winget --exact --disable-interactivity 2>$null | Select-String $t.winget; if ($r) { "ok   $($t.winget)" } else { "FAIL $($t.winget)" } }
```

Optional: `shellcheck shell/*.sh bin/cron2cli bin/k8stool install.sh sync.sh` in WSL (`apt install shellcheck`). Expect only SC1090/SC1091 (dynamic source) notices.

## 2. Unit-style checks for the two non-trivial scripts (no cluster needed)

**cron2cli** builds a jq filter and pipes `kubectl create job --dry-run` through it. Exercise the filter alone:

```bash
fake='{"kind":"Job","spec":{"template":{"spec":{"initContainers":[{"name":"init","image":"busybox","args":["x"]}],"containers":[{"name":"main","image":"orig:1","command":["old"],"args":["a","b"]}]}}}}'
CF='del(.spec.template.spec.containers[0].args) | del(.spec.template.spec.initContainers)'
XF='.spec.template.spec.containers[0].command = $ARGS.positional | del(.spec.template.spec.containers[0].args)'
IF='.spec.template.spec.containers[0].image = $img'
echo "$fake" | jq -c --arg img new:2 "$CF | $IF | $XF" --args -- sleep 3600
# expect: one container "main", image new:2, command ["sleep","3600"], no args, no initContainers
CF='if .spec.template.spec.initContainers then .spec.template.spec.containers = .spec.template.spec.initContainers | del(.spec.template.spec.initContainers) else . end | del(.spec.template.spec.containers[0].args)'
echo "$fake" | jq -c --arg img "" "$CF | . | $XF" --args -- bash -c 'while true; do sleep 25; done'
# expect: container "init", image busybox, command ["bash","-c","while ..."]
bin/cron2cli --help | head -3         # usage text
bin/cron2cli -x; echo "rc=$?"         # "Error: unknown option: -x", rc=1
bin/cron2cli; echo "rc=$?"            # "Error: No cronjob name provided.", rc=1
```

**k8stool** filters `az aks list` output with jq (bash) or `Where-Object` (PowerShell):

```bash
echo '[{"name":"myorg-dev-eastus","fqdn":"a.b","privateFqdn":null,"resourceGroup":"rg1","id":"/subscriptions/1111/resourceGroups/rg1/x"},{"name":"other","fqdn":"c.d","privateFqdn":"p.q","resourceGroup":"rg2","id":"/subscriptions/3333/resourceGroups/rg2/x"}]' |
  jq -c --arg p dev '.[] | select(.name | test($p)) | {name, fqdn, pfqdn: .privateFqdn, rsrc: .resourceGroup, sub: (.id | capture("/subscriptions/(?<s>[^/]+)/").s)}'
# expect exactly one line, name myorg-dev-eastus, sub 1111
bin/k8stool --help; bin/k8stool --bogus; echo "rc=$?"    # usage; "Unknown option", rc=1
```

```powershell
bin\k8stool.ps1 --help; bin\k8stool.ps1 --bogus; $LASTEXITCODE   # usage; "Unknown option: --bogus"; 1
bin\k8stool.ps1                                                    # "no subscriptions given or matched"
```

**Shim generator** must place arguments correctly and keep `pods,jobs,cronjobs` as one argument in PowerShell:

```powershell
.\install.cmd                                            # "gen-shims: N aliases -> ..."
Get-Content bin-win\gen\kbash.cmd                        # @kubectl exec -it %* -- /bin/bash
Select-String "function kl " shell\aliases.generated.ps1 # ... 'pods,jobs,cronjobs' -o wide @args  (quoted)
. .\shell\profile.ps1; function kubectl { ($args | % { "<$_>" }) -join ' ' }; kl -n x; kbash pod -c app
# expect: <get> <pods,jobs,cronjobs> <-o> <wide> <-n> <x>   and   <exec> <-it> <pod> <-c> <app> </bin/bash>
# (PowerShell drops "--" when the callee is a function; it is passed through to real executables)
```

## 3. Smoke tests after install (per platform)

Open a **new** terminal first.

| # | platform | command | expect |
|---|---|---|---|
| 3.1 | cmd.exe | `where kg` | `C:\code\devtools\bin-win\gen\kg.cmd` first (if `C:\code\bin\kg.cmd` is first, PATH order is wrong) |
| 3.2 | cmd.exe | `kc` | echoes `kubectl config get-contexts -o name`, then your contexts |
| 3.3 | cmd.exe | `k8stool --help` | usage from the .ps1 |
| 3.4 | cmd.exe | `docker --version` | `podman version 5.x` (via docker.bat) |
| 3.4b | cmd.exe | `docker ps` | empty table (or your containers). Needs the podman machine running: `podman machine start` after each boot (it does not autostart). If it fails with "unable to connect to Podman socket", start the machine. Verified 2026-10-18: `podman run --rm alpine echo ok` and a `-v C:\code\devtools:/w` mount both work through the shim. |
| 3.4c | cmd.exe | `make --version` | `GNU Make 4.4.1` via `bin-win\make.cmd`, or the "make.exe not found" hint if make is disabled in tools.json |
| 3.5 | cmd.exe | `where docker` | `bin-win\docker.bat` and `bin-win\docker.exe`, no `C:\code\bin\docker.*` |
| 3.6 | PowerShell | `Get-Command kg,kbash,activate,devtools-sync` | all `Function` |
| 3.7 | PowerShell | `kl` | pods, jobs and cronjobs in the current namespace |
| 3.8 | PowerShell | `$env:DEVTOOLS_ROOT` | `C:\code\devtools` |
| 3.9 | Git Bash | `echo $DEVTOOLS_ROOT; type kbash; alias kg` | `/c/code/devtools`, function, alias |
| 3.10 | Git Bash | `which cron2cli jq` | `/c/code/devtools/bin/cron2cli`, a winget path for jq |
| 3.11 | Git Bash | `cron2cli --help` | usage |
| 3.12 | WSL | `readlink -f ~/.bashrc` | `/home/<you>/devtools/bashrc` |
| 3.13 | WSL | `echo $DEVTOOLS_ROOT; which cron2cli fixpod.sh jq mlr uv` | `~/devtools`, all found |
| 3.14 | WSL | `ls -l ~/.bash_aliases` | no such file (old bash_setup link removed) |
| 3.15 | WSL | `echo $PS1 \| head -c 40; git -C ~/devtools status` | coloured prompt string; clean tree |
| 3.16 | WSL | `cron2cli <tab><tab>` in a namespace with cronjobs | completes cronjob names |
| 3.17 | any bash | `time bash -ic exit` | under 1 s on the second run (kubectl completion is cached in `~/.cache/devtools`) |
| 3.18 | devnode | same as WSL, plus the prompt shows `devnode` as host | `IN_MATRIX=yes` |
| 3.19 | devnode | `podman ps; make --version; docker ps` | podman lists containers (rootless, crun); GNU Make 4.3; `docker ps` says permission denied until `sudo usermod -aG docker $USER` and a re-login (dockerd is running) |
| 3.20 | Ubuntu-24.04 | `which podman docker make` | all missing as of 2026-10-18; this distro has no container runtime. Use devnode, or run `sudo bash /mnt/c/code/docker2wsl/bootstraps/data-tools` here for make and `apt install podman` if you want it |
| 3.21 | zsh distro | `grep devtools ~/.zshrc; echo $DEVTOOLS_ROOT; type kbash; alias kg` | the `source .../shell/zshrc` line; `~/devtools`; function; alias |
| 3.22 | zsh distro | `which cron2cli; k get <tab>`; `cron2cli -<tab>` | `~/devtools/bin/cron2cli`; kubectl resource completion; cron2cli options |
| 3.23 | zsh distro | `time zsh -ic exit` | under 1 s on the second run; the prompt is still your theme's |

VS Code: open a dev container project and run **Dev Containers: Reopen in Container**. It must find `docker.exe` (the podman copy); a `.bat` alone fails with "docker not found".

## 4. Sync tests

```powershell
# Windows hub
git -C C:\code\devtools config --get receive.denyCurrentBranch   # updateInstead
.\sync.ps1                                                       # one line per distro: "sync: ok" or "no clone"
```

```bash
# in a WSL clone
devtools-sync --status            # behind=0 ahead=0
echo "# test $(date)" >> ~/.bashrc.local   # per-machine file, NOT in the repo
touch ~/devtools/scratch && devtools-sync   # refuses: "uncommitted changes" (then rm scratch)
git -C ~/devtools commit --allow-empty -m "sync test" && devtools-sync   # "pushed 1 commit(s)"
git -C /mnt/c/code/devtools log -1 --oneline                             # shows "sync test" (hub updated in place)
git -C /mnt/c/code/devtools reset --hard HEAD~1 && git -C ~/devtools reset --hard HEAD~1   # undo
```

The update check (in a WSL clone; the hub is `/mnt/c/code/devtools`):

```bash
git -C /mnt/c/code/devtools commit --allow-empty -m "update test"   # hub moves ahead
bash -i            # "devtools: update available (devtools) - sync now? [y/N]"; answer n, exit
bash -i            # same commits: one-line "run 'devtools-sync'" hint, no prompt; exit
zsh -i             # (zsh distros) same hint; exit
DEVTOOLS_UPDATE_CHECK=off bash -i   # nothing; exit
bash -i            # still the hint; this time run devtools-sync, then exit
bash -i            # nothing: up to date
git -C /mnt/c/code/devtools reset --hard HEAD~1 && git -C ~/devtools reset --hard HEAD~1   # undo
```

## 5. Cluster-dependent checks (need a kubeconfig; run against a dev cluster)

```bash
k8l                                      # contexts
cron2cli <some-cronjob> -n <ns> -d | head -30     # YAML; command is the bash watchdog; no initContainers
cron2cli <some-cronjob> -n <ns>          # job/cli-mainj-<name>-<epoch> created
kbash <its pod> -n <ns>                  # shell inside; exit
cron-keepalive <its pod>                 # prints kubectl top lines every 6 s; Ctrl-C
kubectl delete job -n <ns> -l job-name=cli-mainj-<...>   # cleanup
k8stool --query '<sub-name-regex>' --name '<cluster-regex>'            # dry run lists the steps
k8stool --query '<sub-name-regex>' --name '<cluster-regex>' --install  # PASS for each step
```

`k8stool.ps1` with the same arguments from PowerShell must print the same PASS lines; it also exercises `az`, `kubelogin` and `kubectl` resolution from a Windows PATH.

## 6. Overlay checks

Use two throwaway overlays; nothing here touches a real one. Name order decides precedence: `ov-a` loads first, `ov-b` overrides it.

```bash
# WSL / Linux
for o in a b; do mkdir -p /tmp/ov-$o/shell /tmp/ov-$o/bin; done
echo "alias ovtest='echo from-a'; alias onlya='echo only-a'   #win" > /tmp/ov-a/shell/t.sh
echo "alias ovtest='echo from-b'" > /tmp/ov-b/shell/t.sh
printf '#!/bin/sh
echo bin-a
' > /tmp/ov-a/bin/ovbin; printf '#!/bin/sh
echo bin-b
' > /tmp/ov-b/bin/ovbin
~/devtools/install.sh --overlay /tmp/ov-a --overlay /tmp/ov-b    # "linked ~/devtools/overlays/ov-a ...", same for ov-b
bash -ic 'ovtest; onlya; ovbin'                 # from-b, only-a, bin-b  (b overrides a, a still loaded)
zsh -ic 'ovtest; onlya; ovbin'                  # same under zsh
echo $DEVTOOLS_OVERLAYS                         # (in a new shell) .../overlays/ov-a:.../overlays/ov-b
git -C ~/devtools status --short                # clean: overlays/ is gitignored
rm ~/devtools/overlays/ov-* && rm -rf /tmp/ov-a /tmp/ov-b   # undo
```

```powershell
# Windows
foreach ($o in 'a','b') { New-Item -ItemType Directory -Force $env:TEMP\ov-$o\shell | Out-Null }
"alias ovtest='echo from-a'   #win" | Set-Content -Encoding ascii $env:TEMP\ov-a\shell	.sh
"alias ovtest='echo from-b'   #win" | Set-Content -Encoding ascii $env:TEMP\ov-b\shell	.sh
'function ovps { "ovps-b" }' | Set-Content -Encoding ascii $env:TEMP\ov-b\shell	.ps1
.\install.ps1 -SkipTools -SkipPath -NoDockerShim -Overlay $env:TEMP\ov-a,$env:TEMP\ov-b   # two "overlay: ...overlays\ov-x -> ..." lines
Get-Content bin-win\gen\ovtest.cmd                                       # @echo from-b %*   (b wins: later source, same name)
. .\shell\profile.ps1; ovps; ovtest                                      # ovps-b; from-b
Get-ChildItem overlays                                                    # ov-a, ov-b junctions
cmd /c "rmdir overlays\ov-a & rmdir overlays\ov-b"; Remove-Item -Recurse $env:TEMP\ov-a,$env:TEMP\ov-b; .\install.cmd   # undo: junctions only, then regenerate
```

Migration from the single link: with an old `overlay` link present, either installer moves it into `overlays/<name>` and prints "moved overlay link".

## 7. New distro end to end (container2wsl straps)

Needs [docker2wsl](https://github.com/juaningles/docker2wsl) at `C:\code\docker2wsl` and a working docker/podman. From an elevated cmd:

```cmd
container2wsl.bat ubuntu:24.04 -n dt-test -u tester -b sudo -b devtools -b zsh -b k8s-tools -b data-tools -p uv -p devtools-shell
wsl -d dt-test -- zsh -ic "echo $DEVTOOLS_ROOT; which cron2cli kubectl helm yq mlr uv python; type kbash"
wsl -d dt-test -- bash -ic "readlink -f ~/.bashrc; alias kg"
wsl --unregister dt-test
```

Expect `/home/tester/devtools`, every tool found (`python` from `~/.local/bin`), and the same aliases in bash and zsh.
