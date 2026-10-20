# Commands and aliases

Everything the repo puts on your PATH or in your shell. Platform columns: **W** = Windows cmd.exe / PowerShell, **G** = Git Bash, **L** = WSL / Linux / container.

## bin/ — scripts (G, L; the .ps1 also W)

| command | what it does | needs |
|---|---|---|
| `cron2cli CRONJOB [-i] [-t NAME] [-m IMAGE] [-n NS] [-r CMD] [-c CLUSTER] [-d]` | Creates a Job from a CronJob's pod spec with the command replaced by an idle watchdog (exits after 30 min without anyone exec'd in), so you can `kbash` into a pod that has the cronjob's image, env and mounts. `-i` uses the init container instead. `-r` overrides the command (whitespace-split). `-d` prints YAML instead of applying. | kubectl, jq |
| `cron2job CRONJOB` | Runs a CronJob once now (`kubectl create job --from`) and follows its logs. | kubectl |
| `cron-keepalive POD` | Touches `/root/.bash_history` in POD every 6 s and prints `kubectl top`, which keeps a cron2cli pod's watchdog from expiring during long sessions. Ctrl-C to stop. | kubectl |
| `fixpod.sh POD [-n NS] [-c CLUSTER]` | Re-applies a pod's YAML with `qosClass` and the `job-tracking` annotation stripped (works around a `kubectl replace` rejection). | kubectl |
| `csv2json FILE.csv [...]` | Converts each CSV to `FILE.json` with Miller. | mlr |
| `k8stool [--query REGEX] [--name REGEX] [--install] [SUB-ID ...]` | Lists AKS clusters in the given / matching subscriptions. Without `--install` it prints the commands it would run. With `--install` it runs nslookup, `az aks get-credentials`, `kubelogin convert-kubeconfig -l azurecli` and `kubectl get nodes` per cluster and prints PASS/FAIL. `k8stool.ps1` is the same tool for PowerShell; `k8stool.cmd` wraps it for cmd. | az, jq, kubectl, kubelogin |
| `source venv.sh` | Backward-compatible venv bootstrap for scripts that still source it. Same logic as `activate` below. | uv |

## shell/aliases.sh — aliases and functions

The file is sourced by bash (G, L) and zsh (L). Lines marked `#win` are also generated as cmd shims (`bin-win/gen/*.cmd`) and PowerShell functions, so they work in all three columns. `nogitps1` sets a bash prompt and does nothing useful in zsh.

### kubectl

| alias | expands to | W |
|---|---|---|
| `k` | `kubectl` | yes |
| `kg` | `kubectl get` | yes |
| `kd` | `kubectl describe` | yes |
| `kl` | `kubectl get pods,jobs,cronjobs -o wide` | yes |
| `klogs` | `kubectl logs --follow` | yes |
| `kx` | `kubectl exec -it` | yes |
| `kpods` / `knodes` | `kubectl get pods|nodes -o wide` | yes |
| `kpw` | `kubectl get pod --watch` | yes |
| `kw` | `watch kubectl` | |
| `kbash POD [...]` / `kssh` | `kubectl exec -it POD [...] -- /bin/bash` | yes |
| `ksh POD [...]` | `kubectl exec -it POD [...] -- /bin/sh` | yes |
| `kmux POD` / `kmux2 POD` | exec into a tmux session named after you | |
| `k8l` | `kubectl config get-contexts` | yes |
| `k8s CTX` | `kubectl config use-context CTX` | yes |
| `k8n NS` | `kubectl config set-context --current --namespace NS` | yes |
| `kc` | `kubectl config get-contexts -o name` | yes |
| `kcfor CMD {}` | run CMD once per context name (`xargs -I{}`) | |
| `kxs CMD...` | `kubectl exec -it $KX_TARGET -- CMD...`, a default tools pod; set `KX_TARGET` (e.g. `deploy/toolbox`) in your overlay | |
| `ksql` | `sqlcmd -U sa` inside an in-cluster SQL Server, password from the pod's `$SA_PASSWORD`. `KSQL_SVC` (default `svc/mssql`), `KSQL_NS` (`mssql`) | |
| `ksqlproxy` | port-forward that SQL Server to `localhost:$KSQL_PORT` (default 31433) | |
| `keepalive POD` | `cron-keepalive POD` | |

### containers (`$DOCKER`, default `docker`; set `DOCKER=podman` in your overlay or `~/.bashrc.local`)

| alias | what |
|---|---|
| `di` | images as a table: repo:tag, id, age, size |
| `dive IMAGE` | run wagoodman/dive against the local socket |
| `drun` | `$DOCKER run -it --net=host` |
| `dbash` | `$DOCKER exec -it devnode` |
| `dacr-login ACR` | `az acr login -n ACR` |
| `pacr-login ACR` | az token login for **podman** against `ACR.azurecr.io` (also `bin-win/pacr-login.cmd`) |

### python (uv)

| alias | what |
|---|---|
| `activate` | create/activate `.venv/<distro>` with uv: `uv sync` if `pyproject.toml`, else `uv venv` + `uv pip install -r requirements.txt`. PowerShell twin in `profile.ps1` uses `.venv\Windows`. |
| `noisy` / `quiet` / `med` | pytest presets: debug logging `-xvs`, `-q --tb=no`, WARN `-xvs` |

### misc

| alias | what |
|---|---|
| `ll` `la` `l` | ls variants |
| `randkey` | 64 random url-safe chars |
| `asum` | sum a column of numbers from stdin |
| `hilite PATTERN` | grep that shows all lines and colours matches |
| `squelch` | filter out `[P...]`/`[I...]` log lines |
| `s1` | re-run last command with sudo |
| `cdcode` | `cd ~/code` |
| `nogitps1` | plain prompt without git status |
| `devtools-sync` | see [MAINTENANCE.md](MAINTENANCE.md) |
| `devtools-shims` | regenerate Windows shims |

## bin-win/ — Windows only

| command | what |
|---|---|
| `dsl [NAME] [--image IMG] [--pull\|--stop\|--kill\|--rm]` | start-or-attach to the `devnode` dev container (privileged, mounts `C:\` and `C:\wsl-storage\devnode`). |
| `docker.bat` | `podman %*` for interactive shells. |
| `docker.exe` | a **copy of podman.exe** made by `install.ps1`; required by VS Code Dev Containers, which cannot launch a .bat. Gitignored. |
| `pacr-login ACR` | podman login to an ACR with an az token. |
| `make ...` | wrapper that prepends `C:\Program Files\Git\usr\bin` (so `sh` exists) for this invocation only, then runs the real make.exe. Prints an install hint if make is not installed (it is disabled in `tools.json` by default). |
| `k8stool` | runs `bin/k8stool.ps1`. |
| `gen\*.cmd` | generated shims, one per `#win` alias. |

Importing a container image as a WSL distro is **not** in this repo: use [container2wsl](https://github.com/juaningles/docker2wsl), cloned at `C:\code\docker2wsl` and on PATH as `container2wsl` (tested, supports bootstrap scripts, replaces the old docker2wsl.cmd / podman2wsl.cmd). It calls `docker` or `docker.bat`, so devtools' podman shim on PATH is enough, and the podman machine must be running. Syntax changed from the old scripts: `container2wsl <image> --name NAME --user USER --location DIR`, not `/image /distro /user /storage`. Its straps `k8s-tools`, `data-tools`, `azure-cli`, `uv`, `devtools-shell`, `claude` and `databricks-ug` install everything listed in the "needs" column above, plus devtools itself. Keep your own build recipe (image, name, user, straps) in your overlay's `bin-win/`.

## Overlay — private aliases and scripts

Anything employer- or machine-specific lives in an overlay repo, not here. Its `shell/*.sh` aliases (including `#win` ones), `bin/` scripts and `shell/*.ps1` load after the ones above. See [OVERLAY.md](OVERLAY.md).
