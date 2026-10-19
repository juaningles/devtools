# devtools

One repo for the shell setup and small CLI tools used from **Windows (cmd, PowerShell, Git Bash)**, **WSL distros** and **Linux containers**, under **bash or zsh**. One alias list feeds every shell; Windows gets generated cmd shims and PowerShell functions from it. Private, employer-specific bits live in a separate [overlay](docs/OVERLAY.md) repo.

| doc | what |
|---|---|
| this file | layout, install, how the pieces fit |
| [docs/COMMANDS.md](docs/COMMANDS.md) | every script, alias and function, with platform support |
| [docs/OVERLAY.md](docs/OVERLAY.md) | adding private aliases and scripts without forking |
| [docs/MAINTENANCE.md](docs/MAINTENANCE.md) | adding aliases and tools, sync model, pins, upgrades |
| [TESTING.md](TESTING.md) | how to verify a change on each platform |

## Layout

```
bin/                 bash tools, identical on every platform: cron2cli, cron2job, cron-keepalive,
                     fixpod.sh, csv2json, k8stool, venv.sh  (+ k8stool.ps1, the PowerShell port)
bin-win/             Windows only: dsl.cmd, docker.bat and docker.exe (podman shims), pacr-login.cmd,
                     k8stool.cmd (-> bin/k8stool.ps1), make.cmd, docker2wsl/podman2wsl.cmd
bin-win/gen/         GENERATED cmd shims, one per #win alias            (gitignored)
shell/aliases.sh     THE alias list; lines ending in #win also become Windows commands
shell/env.sh         the only file that sets PATH; completions; tool hooks, all guarded
shell/prompt.sh      the coloured two-line bash prompt
shell/zshrc          zsh entry point: env.sh + aliases + overlay, sourced from ~/.zshrc
shell/profile.ps1    PowerShell profile: dot-sources shell/aliases.generated.ps1 (generated)
shell/completions/   bash completions, auto-sourced (zsh loads them through bashcompinit)
bashrc               stock Debian bashrc + source shell/*.sh + overlay
overlay              optional link to your overlay repo (gitignored), see docs/OVERLAY.md
tools.json           Windows tool manifest for install.ps1 (winget IDs, pins, disabled entries)
install.ps1          Windows setup        install.sh   WSL / Linux setup       install.cmd  rebuild shims
sync.ps1 / sync.sh   keep every clone (and the overlay) in step
```

Binaries are **not** in the repo. `install.ps1` installs them with winget from `tools.json`. On Linux they come from the [docker2wsl](https://github.com/juaningles/docker2wsl) straps (WSL distros) or `install.sh --tools` (bare hosts). The one exception is `bin-win/docker.exe`, a gitignored copy of podman.exe that `install.ps1` creates because VS Code Dev Containers cannot launch a .bat shim.

## Install

### Windows

From PowerShell, in the clone:

```powershell
cd C:\code\devtools
.\install.ps1                              # winget tools, docker.exe shim, user PATH, $PROFILE, Git Bash ~/.bashrc, cmd shims
.\install.ps1 -Wsl Ubuntu-24.04,devnode    # also clone into those distros and run install.sh there
.\install.ps1 -SkipTools -Overlay C:\code\my-overlay   # optional: link a private overlay
```

What it changes on the machine:

| item | change |
|---|---|
| tools | `winget install` for each entry in `tools.json` that is missing (or not at its pin) |
| `bin-win\docker.exe` | copied from podman.exe unless a real Docker is installed; skip with `-NoDockerShim` |
| user PATH | prepends `bin-win`, `bin-win\gen`, `bin` (the last so Git Bash finds the bash scripts), and the overlay's `bin-win` if present |
| `$PROFILE.CurrentUserAllHosts` | appends one line that dot-sources `shell\profile.ps1` |
| `%USERPROFILE%\.bashrc` | appends one line that sources the repo `bashrc`, for Git Bash |
| `overlay` | with `-Overlay DIR`: a junction to DIR |
| repo git config | `receive.denyCurrentBranch=updateInstead`, `pull.ff=only`, so WSL clones can push back |

It is idempotent. Flags: `-SkipTools`, `-SkipPath`, `-NoDockerShim`, `-Wsl <names>`, `-Overlay <dir>`. Open a new terminal afterwards.

### A new WSL distro (container2wsl)

[container2wsl](https://github.com/juaningles/docker2wsl) builds a distro from an image and runs "straps" in it. The tools and devtools itself come from its built-in straps:

```cmd
container2wsl.bat ubuntu:24.04 -n dev -u alice ^
  -b sudo -b devtools -b zsh -b k8s-tools -b data-tools -b azure-cli ^
  -p powerlevel10k -p uv -p devtools-shell
```

`devtools-shell` clones `C:\code\devtools` (or `%C2W_DEVTOOLS_REPO%`, or GitHub) to `~/devtools` and runs `install.sh`. Add your overlay's own poststrap after it ([docs/OVERLAY.md](docs/OVERLAY.md)).

### An existing WSL distro / Linux host / container

Either via `install.ps1 -Wsl` above, or by hand:

```bash
/mnt/c/code/devtools/install.sh --from /mnt/c/code/devtools        # clone to ~/devtools, link ~/.bashrc, hook ~/.zshrc
~/devtools/install.sh --overlay ~/my-overlay                       # optional: link an overlay
~/devtools/install.sh --tools                                      # bare Linux hosts only: install the CLI tools
```

What it changes: backs up a real `~/.bashrc` to `~/.bashrc.pre-devtools` and symlinks `~/.bashrc` to the clone. If zsh is installed (or `~/.zshrc` exists) it appends one line to `~/.zshrc` that sources `shell/zshrc`, so Oh My Zsh and powerlevel10k keep owning that file. It also runs `chmod +x bin/*`. With `--tools`: `jq`, `miller` and `make` via apt or apk, `uv` via astral.sh, and `kubectl`, `kubelogin`, `yq`, `helm` into `~/.local/bin` if missing. On an existing WSL distro you can also run the container2wsl straps directly: `sudo bash /mnt/c/code/docker2wsl/bootstraps/k8s-tools`. Per-machine extras go in `~/.bashrc.local`.

### After install

Start a new shell and run `k8l` (any platform), `cron2cli --help` (bash or zsh), `kg.cmd` (cmd.exe). [TESTING.md](TESTING.md) has the full checklist.

## How it fits together

**Startup, bash.** `~/.bashrc` is a symlink to `bashrc`, which sources `shell/env.sh` (PATH, completions), `shell/prompt.sh`, `shell/aliases.sh`, then the overlay's `shell/*.sh` and `~/.bashrc.local` if present. `DEVTOOLS_ROOT` is derived from the symlink's real path, so a clone can live anywhere.

**Startup, zsh.** `~/.zshrc` sources `shell/zshrc`, which sets `DEVTOOLS_ROOT` from its own path and then sources the same `env.sh`, `aliases.sh` and overlay. It leaves the prompt to your theme. When compinit has run (Oh My Zsh), it adds cached kubectl zsh completion (also for `k`) and loads the bash completion files through `bashcompinit`.

**Startup, PowerShell.** `$PROFILE` dot-sources `shell/profile.ps1`, which loads the generated functions and the overlay's `shell/*.ps1`. PATH is not touched here; it was written once by `install.ps1`.

**cmd.exe.** Has no startup file, so each `#win` alias is a tiny `.cmd` in `bin-win/gen` that echoes the expanded command and runs it.

**Aliases.** Edit `shell/aliases.sh` (or an overlay `shell/*.sh`) only. It is sourced by bash and zsh, so it stays POSIX-ish. Two shapes are understood by the generator:

```bash
alias kg='kubectl get'                              #win   # args appended
kbash() { kubectl exec -it "$@" -- /bin/bash; }     #win   # "$@" marks where args go
```

`#win` means "also a cmd.exe command and a PowerShell function". Leave it off anything that needs bash. Run `install.cmd` (or `devtools-shims`) to regenerate.

**Sync.** The Windows clone is the origin for each WSL clone (`file://` over `/mnt/c`, works offline). `sync.ps1` from Windows updates every distro; `devtools-sync` from any clone pulls and pushes back. Both also sync the overlay if it is a git clone. Details in [docs/MAINTENANCE.md](docs/MAINTENANCE.md).

**Tool versions.** `tools.json` floats everything to latest except explicit pins. `make` is in the `_disabled` list on Windows: GnuWin32 3.81 can be blocked by application-control policy, and `ezwinports.make` 4.4.1 works when `sh` is on PATH, which `bin-win\make.cmd` provides per invocation. Flip it on by moving the entry back into `tools`. On Linux make comes from the `data-tools` strap or `install.sh --tools`.

**Containers on Windows** go through podman. `docker.bat` and `docker.exe` in `bin-win` are shims to it, and the podman machine must be running (`podman machine start` after a reboot).

## License

MIT, see [LICENSE](LICENSE).
