# recipes/

Distro recipes for devtools' `rebuild-wsl` (devtools `bin-win/rebuild-wsl.bat`): one `<name>.conf`
per WSL distro, run from an elevated cmd or PowerShell with `rebuild-wsl <name>`. Arguments after
the name go to container2wsl after the recipe's defaults, so `-n`, `-u`, `--force` and `--dry-run`
override and extra `-b` / `-p` straps add. `rebuild-wsl` alone lists every recipe in every overlay.

Format: `key=value` lines with no spaces around `=`; comments are whole lines starting with `#`.

```ini
# dev - what this distro is for
image=docker.io/library/ubuntu:24.04       # required
name=dev                                   # optional, defaults to the file name
user=alice                                 # optional
# location=D:\wsl                          # optional, container2wsl -l
bootstraps=sudo systemd-enable devtools zsh motd k8s-tools data-tools
poststraps=powerlevel10k uv devtools-shell devtools-overlay ssh-keys keychain
# extra=--force                            # optional raw arguments, passed verbatim
```

(The trailing comments above are for this README only; in a real file keep comments on their own line.)
If two overlays define the same recipe name, the overlay that loads last (name order) wins.
