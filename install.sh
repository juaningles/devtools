#!/bin/bash
# install.sh - set up devtools in WSL / Linux / a container.
#
#   ~/devtools/install.sh                 # link ~/.bashrc, hook ~/.zshrc, make bin/ executable
#   ~/devtools/install.sh --overlay DIR   # also link DIR as an overlay (repeatable; docs/OVERLAY.md)
#   ~/devtools/install.sh --tools         # bare Linux hosts only: jq, miller, make, uv, kubectl, kubelogin, yq, helm
#   install.sh --from /mnt/c/code/devtools [--dest ~/devtools]   # bootstrap: clone first
#
# Distros made with container2wsl get their tools from its straps instead of --tools:
#   -b k8s-tools -b data-tools -b azure-cli -p uv -p devtools-shell
#
# The Windows clone (C:\code\devtools, seen as /mnt/c/code/devtools) is the
# origin for every WSL clone; sync.sh pulls from it and can push back.
set -euo pipefail

FROM="" DEST="$HOME/devtools" TOOLS=no OVERLAYS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM="$2"; shift 2;;
    --dest) DEST="$2"; shift 2;;
    --tools) TOOLS=yes; shift;;
    --overlay) OVERLAYS="$OVERLAYS
$2"; shift 2;;
    -h|--help) sed -n '2,13p' "$0"; exit 0;;
    *) echo "unknown option: $1" >&2; exit 1;;
  esac
done

if [ -n "$FROM" ]; then
  if [ -d "$DEST/.git" ]; then git -C "$DEST" pull --ff-only; else git clone "$FROM" "$DEST"; fi
  ROOT="$DEST"
else
  ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
fi
echo "devtools root: $ROOT"

chmod +x "$ROOT"/bin/* "$ROOT"/sync.sh "$ROOT"/install.sh 2>/dev/null || true
git -C "$ROOT" config pull.ff only 2>/dev/null || true

# --- ~/.bashrc -> repo/bashrc ---------------------------------------------------
link_rc() {
  local target="$1" link="$2"
  if [ -L "$link" ]; then
    rm -f "$link"
  elif [ -f "$link" ]; then
    mv "$link" "$link.pre-devtools" && echo "backed up $link -> $link.pre-devtools (move anything you still want into ~/.bashrc.local)"
  fi
  ln -s "$target" "$link" && echo "linked $link -> $target"
}
link_rc "$ROOT/bashrc" "$HOME/.bashrc"

# --- ~/.zshrc: one source line; Oh My Zsh / powerlevel10k keep owning the file -------
# Run after zsh / Oh My Zsh are installed: the OMZ installer replaces an existing ~/.zshrc.
if command -v zsh >/dev/null 2>&1 || [ -f "$HOME/.zshrc" ]; then
  if ! grep -qF "$ROOT/shell/zshrc" "$HOME/.zshrc" 2>/dev/null; then
    printf '\n# devtools\n[ -f "%s" ] && source "%s"\n' "$ROOT/shell/zshrc" "$ROOT/shell/zshrc" >> "$HOME/.zshrc"
    echo "hooked $HOME/.zshrc -> $ROOT/shell/zshrc"
  fi
fi

# old setup used ~/.bash_aliases -> /mnt/c/code/bash_setup/bash_aliases; drop that link
if [ -L "$HOME/.bash_aliases" ] && readlink "$HOME/.bash_aliases" | grep -q bash_setup; then
  rm -f "$HOME/.bash_aliases" && echo "removed old ~/.bash_aliases symlink (aliases now come from devtools)"
fi

# --- overlays: one symlink per repo in $ROOT/overlays/<name>, loaded in name order -------
mkdir -p "$ROOT/overlays"
if [ -L "$ROOT/overlay" ]; then   # pre-2026-10-20 single link: move it into overlays/
  _t="$(readlink -f "$ROOT/overlay")"
  ln -sfn "$_t" "$ROOT/overlays/$(basename "$_t")" && rm -f "$ROOT/overlay" && echo "moved overlay link -> overlays/$(basename "$_t")"
fi
printf '%s\n' "$OVERLAYS" | sed '/^$/d' | while IFS= read -r _ov; do
  _ov="$(cd "$_ov" && pwd)" || continue
  _link="$ROOT/overlays/$(basename "$_ov")"
  if [ -e "$_link" ] && [ ! -L "$_link" ]; then
    echo "overlay: $_link exists and is not a symlink; leaving it alone" >&2
  else
    ln -sfn "$_ov" "$_link" && echo "linked $_link -> $_ov"
  fi
done
for _d in "$ROOT"/overlays/*/bin; do [ -d "$_d" ] && chmod +x "$_d"/* 2>/dev/null; done; true

# --- tools -------------------------------------------------------------------------
if [ "$TOOLS" = yes ]; then
  BIN="$HOME/.local/bin"; mkdir -p "$BIN"
  arch=$(uname -m); case "$arch" in x86_64) garch=amd64;; aarch64|arm64) garch=arm64;; *) garch=$arch;; esac
  SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null && SUDO=sudo

  if command -v apt-get >/dev/null; then
    # make lives here rather than on Windows: docker-driving Makefiles are happiest next to a
    # Linux container runtime.
    $SUDO apt-get update -qq && $SUDO apt-get install -y -qq jq miller make curl ca-certificates
  elif command -v apk >/dev/null; then
    $SUDO apk add --no-cache jq miller make curl
  else
    echo "no apt/apk: install jq and miller (mlr) manually"
  fi

  command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh

  if ! command -v kubectl >/dev/null; then
    v=$(curl -Ls https://dl.k8s.io/release/stable.txt)
    curl -Lo "$BIN/kubectl" "https://dl.k8s.io/release/$v/bin/linux/$garch/kubectl" && chmod +x "$BIN/kubectl"
  fi
  if ! command -v kubelogin >/dev/null; then
    curl -Ls "https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-$garch.zip" -o /tmp/kubelogin.zip \
      && (cd /tmp && unzip -oq kubelogin.zip && install -m 755 "bin/linux_$garch/kubelogin" "$BIN/kubelogin" && rm -rf kubelogin.zip bin)
  fi
  command -v yq >/dev/null || { curl -Ls "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$garch" -o "$BIN/yq" && chmod +x "$BIN/yq"; }
  command -v helm >/dev/null || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | HELM_INSTALL_DIR="$BIN" USE_SUDO=false bash
  echo "tools: az CLI is not installed here; see https://aka.ms/InstallAzureCLIDeb if you need it inside WSL"
fi

echo
echo "done. Start a new shell (or: exec bash). Sync later with: devtools-sync"
