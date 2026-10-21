# Overlays: private aliases and scripts on top of devtools

devtools holds only generic tooling. Aliases, hosts, image names, ssh material and scripts that belong to one person, employer, customer or machine go in an **overlay**: a separate directory, usually its own private git repo, that devtools loads after its own files. There can be several, for example `devtools-private` (yours, every machine) plus `devtools-unisys` (work machines only).

## How devtools finds them

`devtools/overlays/` holds one link per overlay, named after the overlay's folder. They load in **name order**, and a later overlay overrides an earlier one (aliases, functions, PATH). So `devtools-private` loads before `devtools-unisys`, and the work overlay wins where both define something. `DEVTOOLS_OVERLAYS` (a `:` list on Linux, `;` on Windows) replaces the whole list when set before `bashrc`/`zshrc`/`profile.ps1` run. The folder is gitignored.

| where | link | made by |
|---|---|---|
| Windows | `devtools\overlays\<name>` -> `..\<name>` (junction, no admin needed) | `.\install.ps1 -SkipTools -Overlay ..\devtools-private,..\devtools-unisys` |
| WSL / Linux | `~/devtools/overlays/<name>` -> `~/<name>` (symlink) | `~/devtools/install.sh --overlay ~/devtools-private --overlay ~/devtools-unisys` |

Both installers move the pre-2026-10-20 single `overlay` link into `overlays/` on their first run; it keeps working until then.

## Layout (every part optional)

```
my-overlay/
  .devtools-overlay   empty marker: container2wsl auto-detects sibling folders that have it
  shell/*.sh          sourced by bash and zsh after shell/aliases.sh, in name order
                      lines ending in "#win" also become cmd shims and PowerShell functions
  shell/*.ps1         dot-sourced by shell/profile.ps1, in name order
  bin/                prepended to PATH in bash/zsh (ahead of devtools/bin)
  bin-win/            prepended to the Windows user PATH by install.ps1
  recipes/            <name>.conf distro recipes for rebuild-wsl (image, user, straps); see templates/overlay/recipes/README.md
  straps/             container2wsl straps, resolvable by bare name once the overlay is detected
  ssh/                source for the container2wsl ssh-keys poststrap (never commit private keys)
```

`shell/*.sh` is sourced by **both** bash and zsh, so keep it to aliases, simple functions and exports. Put bash-only logic behind `[ -n "$BASH_VERSION" ]`.

## Sync

Every overlay that is a git clone is synced by `devtools-sync` (WSL) and `sync.ps1` (Windows) right after devtools, with the same model: the Windows clone is the origin for WSL clones, fast-forward only, local commits pushed back. Give each Windows clone `receive.denyCurrentBranch=updateInstead` so WSL clones can push to it. The shell-start update check covers overlays too.

## Example

```bash
# my-overlay/shell/work.sh
export DOCKER=podman
alias ktool='kubectl exec -it deploy/toolbox --'           #win
alias jump='ssh jumphost -t tmux new -A -s main'
```

After adding `#win` lines, run `install.cmd` (or `devtools-shims`) on Windows to regenerate the shims.

## Creating an overlay

`templates/overlay` holds the boilerplate every overlay shares and implements the layout above: the
`.devtools-overlay` marker, `.gitignore` (ignores `ssh/` except its README), `.gitattributes`, name-agnostic
`install.ps1` / `install.sh` (they derive the overlay name from their own folder), `ssh/README.md`, a
`README.md` skeleton and a `shell/<name>.sh` stub. The two things that differ between overlays are the
content (`shell/`, `bin-win/`, `docs/`, the README text) and the folder name.

```powershell
.\tools\new-overlay.ps1 -Name devtools-foo [-Path D:\src]   # create next to devtools (default), git init, link it
.\tools\new-overlay.ps1 -Update ..\devtools-foo              # refresh only the boilerplate files of an existing overlay
```

```bash
devtools-new-overlay devtools-foo [DIR]       # create DIR/devtools-foo (default ~), git init, link it
devtools-new-overlay --update ~/devtools-foo  # refresh only the boilerplate files
```

`-Update` / `--update` copies exactly `install.ps1`, `install.sh`, `.gitignore`, `.gitattributes`,
`.devtools-overlay` and `ssh/README.md`; it never touches `README.md`, `shell/`, `bin-win/` or `docs/`.
Review the diff in the overlay and commit it there. When the template changes, run it on every overlay.
The create step links the new overlay into the devtools clone the tool lives in (`DEVTOOLS_ROOT`
overrides that in bash); if git has no `user.email` the files are left staged for you to commit.

## With container2wsl

[container2wsl](https://github.com/juaningles/docker2wsl) detects sibling folders of its own clone that contain a `.devtools-overlay` marker (or takes `--private DIR`). Its `devtools-shell` poststrap installs devtools, and `devtools-overlay` clones every detected overlay into the distro and links it. Nothing overlay-specific is needed in the recipe:

```cmd
container2wsl.bat ubuntu:24.04 -n dev ... -p uv -p devtools-shell -p devtools-overlay
```

Keep that command as a recipe in your overlay, `recipes/dev.conf` (image, name, user, bootstraps, poststraps), and run it with devtools' `rebuild-wsl dev` from an elevated cmd. Arguments after the name go to container2wsl last, so `rebuild-wsl dev -n dev2 --dry-run` overrides and `-p keychain` adds. `rebuild-wsl` alone lists every recipe in every overlay; the format is in `templates/overlay/recipes/README.md`.
