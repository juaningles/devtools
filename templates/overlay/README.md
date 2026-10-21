# {{NAME}}

Overlay for [devtools](https://github.com/juaningles/devtools): ONE LINE ON WHAT THIS OVERLAY HOLDS AND
WHERE IT IS HOSTED. devtools loads it through its overlay hook (devtools `docs/OVERLAY.md`); overlays load
in name order and a later one overrides an earlier one.

| path | what |
|---|---|
| `.devtools-overlay` | marker: container2wsl auto-detects this folder when it sits next to `docker2wsl`, and its `devtools-overlay` poststrap installs it into new distros |
| `shell/{{NAME}}.sh` | aliases, functions and exports, sourced by bash and zsh |
| `ssh/` | source for the container2wsl `ssh-keys` poststrap. **Never tracked** except its README; see `ssh/README.md` |
| `bin-win/` | Windows scripts; on PATH through the overlay |
| `recipes/` | `<name>.conf` distro recipes for `rebuild-wsl <name>`; see `recipes/README.md` |
| `install.ps1` / `install.sh` | link this repo as a devtools overlay (Windows junction / WSL symlink) |

The boilerplate (`install.*`, `.gitignore`, `.gitattributes`, `ssh/README.md`) comes from devtools
`templates/overlay`; refresh it with `devtools\tools\new-overlay.ps1 -Update <this folder>`.

## What is here

DESCRIBE THE CONTENT: aliases, recipes, docs.

## Setup

Clone next to `devtools` and `docker2wsl`:

```powershell
git clone <repo-url> {{NAME}}
.\{{NAME}}\install.ps1              # junction devtools\overlays\{{NAME}} -> here, regenerate shims
.\{{NAME}}\install.ps1 -Wsl zdev    # also clone + link inside existing distros
```

New distro: `rebuild-wsl <recipe>` from an elevated cmd, with a recipe from `recipes/` (`-n NAME`, `--force`,
`--dry-run` go after the name); its `-p devtools-overlay` installs every detected overlay, `-p ssh-keys` the keys from `ssh/`.

Existing distro, by hand: `bash /mnt/<drive>/.../{{NAME}}/install.sh --from /mnt/<drive>/.../{{NAME}}`.

## Sync

Same model as devtools: the Windows clone is the origin for WSL clones (`install.ps1` sets
`receive.denyCurrentBranch=updateInstead`), and its own `origin` is the hosted repo. `devtools-sync` (WSL)
and devtools' `sync.ps1` (Windows) sync this repo right after devtools.

## Rules

- No secrets in git: `ssh/` is ignored wholesale, and nothing else here may hold a key or token.
- `shell/*.sh` is sourced by bash and zsh: aliases, simple functions and exports only.
