# Maintenance

## Day to day

| task | command | where |
|---|---|---|
| Add or change an alias | edit `shell/aliases.sh`, then `install.cmd` (or `devtools-shims`) | any; shims only matter on Windows |
| Add a script | drop it in `bin/` (bash) or `bin-win/` (Windows), `git add`, and `git update-index --chmod=+x bin/<name>` if you added it from Windows | any |
| Add a work / private alias | your overlay's `shell/*.sh` ([OVERLAY.md](OVERLAY.md)), commit there | overlay repo |
| Per-machine tweak | `~/.bashrc.local` (bash), `~/.zshrc` below the devtools line (zsh), or an overlay `shell/*.ps1` (PowerShell) | each machine |
| Pull changes into every clone | `.\sync.ps1` from Windows, or `devtools-sync` in one clone | Windows hub |
| Add / pin / unpin a Windows tool | edit `tools.json`, then `.\install.ps1 -SkipPath` | Windows |
| Rebuild the docker.exe shim after a podman upgrade | `.\install.ps1 -SkipTools -SkipPath` | Windows |

## How sync works

```
C:\code\devtools  (Windows clone = origin, receive.denyCurrentBranch=updateInstead)
   ^  pull / push (file:// over /mnt/c)                 ^
   |                                                     |
~/devtools in Ubuntu-24.04                 ~/devtools in devnode   ...
```

- `sync.ps1` (Windows): pulls the hub from its remote if one is configured, then runs `sync.sh` inside every WSL distro that has `~/devtools`, then regenerates shims. `-Wsl name,name` limits it.
- `sync.sh` / `devtools-sync` (any clone): refuses if the tree is dirty, fetches, fast-forwards, and pushes local commits back to the hub. `--status` only reports ahead/behind.
- Shell start checks whether the hub has commits this clone (or an overlay) lacks: one `git ls-remote` per repo over `/mnt/c`, about 70 ms, and only when the origin is a local path, so it never touches the network. If so it asks `devtools: update available (devtools) - sync now? [y/N]` (10 s timeout, default no); **y** runs `devtools-sync`. A "no" is remembered for those commits, and later shells print a one-line hint until something newer arrives. `DEVTOOLS_UPDATE_CHECK=hint` only prints, `off` disables it (set it in `~/.bashrc.local` or before the devtools line in `~/.zshrc`). It never syncs without asking.
- Commit where you edited. Fast-forward only: if two clones diverge, resolve in one of them and sync again.
- The Windows clone's own `origin` is the hosted repo (GitHub); `sync.ps1` pulls from it first. WSL clones keep pointing at the hub and need no change.
- Every overlay that is a git clone is synced the same way, right after devtools, in load order.

## tools.json

Only the `tools` array is installed. Each entry: `name`, `winget` (exact ID), optional `pin` (exact version, never auto-upgraded), optional `scope: user`, optional `note`. `_disabled` holds entries kept for reference; move an object back into `tools` to re-enable it.

Current policy:

- Everything floats to latest except what is pinned.
- **make** is in `_disabled` (2026-10-18). GnuWin32 3.81 can be blocked by endpoint application-control policy. Make was on Windows because docker-driving Makefiles needed Docker Desktop when Docker inside WSL was unreliable. Today both sides work: Windows podman (once its machine is started) and a WSL distro with podman/dockerd. `ezwinports.make` 4.4.1 was dry-run tested against a set of real Makefiles on 2026-10-18 and works, with `sh` on PATH, which `bin-win\make.cmd` arranges per invocation. The risk on Windows is the shell, not the make version: POSIX recipes fail without `sh.exe`, and Makefiles that special-case a missing `sh.exe` (`$(shell cmd /c ...)`) misbehave once it is present. To enable on Windows, move the entry from `_disabled` back into `tools` and run `.\install.ps1 -SkipPath`. On Linux make comes from the `data-tools` strap or `install.sh --tools`.
- **podman on Windows** is the CLI plus a WSL VM (`podman-machine-default`). The VM does not autostart: run `podman machine start` after a reboot, or register a logon task for it. `docker.bat`, `docker.exe`, `dsl.cmd` and VS Code Dev Containers all depend on it being up.
- **helm** floats and installs Helm 4; add `"pin": "3.22.1"` if a chart breaks.
- IDs were verified with `winget search --id <id> --exact` on 2026-10-18. Re-verify before adding new ones.

`install.ps1` is idempotent: it skips tools winget already reports installed (and, for pinned entries, at the pinned version), re-adds missing PATH entries only, and appends profile lines only once.

## Upgrading tools

| tool | how |
|---|---|
| anything in `tools.json` without a pin | `winget upgrade --id <id>` or `winget upgrade --all` |
| pinned tool | change `pin`, run `.\install.ps1 -SkipPath` |
| uv | `uv self update` (works everywhere) |
| WSL tools from the container2wsl straps (`/usr/local/bin`) | delete the binary, then re-run the strap: `sudo bash /mnt/c/code/docker2wsl/bootstraps/k8s-tools` (it only installs what is missing) |
| WSL tools from `install.sh --tools` (`~/.local/bin`) | same idea: delete the old binary first, then re-run `install.sh --tools` |
| uv-managed Python | `uv python upgrade`, or `uv python install --default 3.x` |

## Recovering

- Old `~/.bashrc` on a distro: `install.sh` saved it as `~/.bashrc.pre-devtools`.
- A broken shell after an alias edit: `bash --norc` (or `zsh -f`), fix `shell/aliases.sh`, `exec bash`.
- Remove the zsh hook: delete the two `# devtools` lines `install.sh` appended to `~/.zshrc`.
