# shell/env.sh - environment: PATH, completions, tool hooks.
# THIS IS THE ONLY FILE THAT MODIFIES PATH. Every line is guarded so the same
# file works in WSL, bare Linux, a devnode container and Git Bash on Windows,
# under bash or zsh (shell/zshrc sets DEVTOOLS_ROOT first; completions are bash-only).

# Resolve the repo root from this file's real location (works through symlinks).
DEVTOOLS_ROOT="${DEVTOOLS_ROOT:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
export DEVTOOLS_ROOT
# Optional overlay repo (private aliases, scripts): a symlink/junction at $DEVTOOLS_ROOT/overlay
# or any directory named here. Layout and contract: docs/OVERLAY.md.
DEVTOOLS_OVERLAY="${DEVTOOLS_OVERLAY:-$DEVTOOLS_ROOT/overlay}"
export DEVTOOLS_OVERLAY

# Append-once PATH helper (prepend so repo tools win over system copies).
_path_prepend() { [ -d "$1" ] && case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH";; esac; }

_path_prepend "$HOME/.local/bin"                       # uv, pipx, user installs
_path_prepend "${KREW_ROOT:-$HOME/.krew}/bin"          # kubectl krew plugins
_path_prepend "$HOME/.cargo/bin"
_path_prepend "$DEVTOOLS_ROOT/bin"
_path_prepend "$DEVTOOLS_OVERLAY/bin"                  # overlay scripts win over repo ones
export PATH

# Container engine used by aliases (override in the overlay or ~/.bashrc.local: DOCKER=podman).
export DOCKER="${DOCKER:-docker}"

# ls: make "other-writable" dirs readable on dark terminals (WSL /mnt/c).
export LS_COLORS="${LS_COLORS}:ow=01;36;40"

# ssh-agent via keychain, only where it exists.
if command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --agents ssh --quiet $(cat ~/.keychain_default_keys 2>/dev/null || echo "$HOME/.ssh/id_rsa") 2>/dev/null)"
fi

# --- completions ---------------------------------------------------------------
if [ -n "$BASH_VERSION" ]; then
  if command -v kubectl >/dev/null 2>&1; then
    # kubectl completion is slow to generate; cache it per kubectl version.
    _kc="${XDG_CACHE_HOME:-$HOME/.cache}/devtools/kubectl-completion-$(kubectl version --client -o json 2>/dev/null | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p').bash"
    if [ ! -s "$_kc" ]; then mkdir -p "$(dirname "$_kc")" && kubectl completion bash > "$_kc" 2>/dev/null; fi
    # shellcheck disable=SC1090
    [ -s "$_kc" ] && source "$_kc" && complete -o default -F __start_kubectl k
    unset _kc
  fi
  for _f in "$DEVTOOLS_ROOT"/shell/completions/*.completion; do
    # shellcheck disable=SC1090
    [ -r "$_f" ] && source "$_f"
  done
  unset _f
fi

# --- staleness hint (keeps clones in sync; see sync.sh) --------------------------
if [ -d "$DEVTOOLS_ROOT/.git" ] && [ -t 1 ]; then
  _stamp="$DEVTOOLS_ROOT/.git/FETCH_HEAD"
  if [ ! -f "$_stamp" ] || [ -n "$(find "$_stamp" -mtime +7 2>/dev/null)" ]; then
    echo "devtools: clone not synced in 7+ days - run 'devtools-sync'"
  fi
  unset _stamp
fi
