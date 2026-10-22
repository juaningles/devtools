# recipes/

Build recipes for [docker2wsl](https://github.com/juaningles/docker2wsl): one `<name>.conf` per WSL
distro or container. docker2wsl finds them in the `recipes/` folder of every private overlay it detects
(`--private`, `C2W_PRIVATE_DIRS`, or sibling folders with a `.devtools-overlay` marker). The same file
works with these docker2wsl commands (`rebuild-*` are shorthands for `--recipe`):

| command | builds | where |
|---|---|---|
| `rebuild-wsl <name>` = `container2wsl.bat --recipe <name>` | a WSL distro | Windows, elevated cmd or PowerShell |
| `rebuild-wsl <name> --target container` | a running docker/podman container | Windows |
| `rebuild-container <name>` = `container2x.sh --recipe <name>` | a running container: docker, podman or Apple `container` | macOS, Linux |

Arguments after the name go to the builder after the recipe's defaults, so `-n`, `-u`, `--force`,
`--dry-run`, `--engine`, `--arch` and `--commit` override and extra `-b` / `-p` straps add.
`rebuild-wsl` or `rebuild-container` alone (or `--recipes`) lists every recipe in every overlay.

Format: `key=value` lines with no spaces around `=`; comments are whole lines starting with `#`.

```ini
# dev - what this distro is for
image=docker.io/library/ubuntu:24.04       # required
name=dev                                   # optional, defaults to the file name
user=alice                                 # optional
# location=D:\wsl                          # optional, container2wsl -l (rebuild-wsl only)
bootstraps=sudo systemd-enable devtools zsh motd k8s-tools data-tools
poststraps=powerlevel10k uv devtools-shell devtools-overlay ssh-keys keychain
# target=container                         # optional, rebuild-wsl: build a container, not a distro
# commit=localhost/dev:1                   # optional, container builds only: also save an image
# engine=apple                             # optional, rebuild-container: docker, podman or apple
# arch=arm64                               # optional, rebuild-container: image architecture
# extra=--force                            # optional raw arguments, passed verbatim
```

(The trailing comments above are for this README only; in a real file keep comments on their own line.)
`commit=` only applies when the build is a container, so a WSL recipe can carry it safely.
Straps that only make sense in WSL (`systemd-enable`, `podman-machine`) skip themselves in a container.
If two overlays define the same recipe name, the overlay that loads last (name order) wins.
