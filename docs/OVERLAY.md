# Overlays: private aliases and scripts on top of devtools

devtools holds only generic tooling. Aliases, hosts, image names and scripts that belong to one employer, customer or machine go in an **overlay**: a separate directory, usually its own private git repo, that devtools loads after its own files.

## How devtools finds it

`$DEVTOOLS_OVERLAY`, default `$DEVTOOLS_ROOT/overlay`. That path is gitignored and is normally a link:

| where | link | made by |
|---|---|---|
| Windows | `C:\code\devtools\overlay` -> `C:\code\my-overlay` (junction, no admin needed) | `.\install.ps1 -SkipTools -Overlay C:\code\my-overlay` |
| WSL / Linux | `~/devtools/overlay` -> `~/my-overlay` (symlink) | `~/devtools/install.sh --overlay ~/my-overlay` |

Set `DEVTOOLS_OVERLAY` yourself only if you want it somewhere else; it must be set before `bashrc`/`zshrc`/`profile.ps1` run.

## Layout (every part optional)

```
my-overlay/
  shell/*.sh       sourced by bash and zsh after shell/aliases.sh, in name order
                   lines ending in "#win" also become cmd shims and PowerShell functions
  shell/*.ps1      dot-sourced by shell/profile.ps1, in name order
  bin/             prepended to PATH in bash/zsh (ahead of devtools/bin)
  bin-win/         prepended to the Windows user PATH by install.ps1
```

`shell/*.sh` is sourced by **both** bash and zsh, so keep it to aliases, simple functions and exports. Put bash-only logic behind `[ -n "$BASH_VERSION" ]`.

## Sync

If the overlay is a git clone, `devtools-sync` (WSL) and `sync.ps1` (Windows) sync it along with devtools, using the same model: the Windows clone is the origin for WSL clones, fast-forward only, and local commits are pushed back. Give the Windows clone `receive.denyCurrentBranch=updateInstead` so WSL clones can push to it.

## Example

```bash
# my-overlay/shell/work.sh
export DOCKER=podman
alias ktool='kubectl exec -it deploy/toolbox --'           #win
alias jump='ssh jumphost -t tmux new -A -s main'
```

After adding `#win` lines, run `install.cmd` (or `devtools-shims`) on Windows to regenerate the shims.

## With container2wsl

A new distro gets devtools from the [docker2wsl](https://github.com/juaningles/docker2wsl) `devtools-shell` poststrap. Keep a poststrap for your overlay in the overlay repo itself and pass it by path after `devtools-shell`:

```bash
# my-overlay/straps/overlay  (poststrap: runs as the distro user)
if [ -d $HOME/my-overlay/.git ]; then git -C $HOME/my-overlay pull --ff-only; else git clone /mnt/c/code/my-overlay $HOME/my-overlay; fi
bash $HOME/devtools/install.sh --overlay $HOME/my-overlay
```

```cmd
container2wsl.bat ubuntu:24.04 -n dev ... -p uv -p devtools-shell -p C:\code\my-overlay\straps\overlay
```
