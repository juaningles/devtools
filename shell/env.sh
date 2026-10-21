# shell/env.sh - environment: PATH, completions, tool hooks.
# THIS IS THE ONLY FILE THAT MODIFIES PATH. Every line is guarded so the same
# file works in WSL, bare Linux, a devnode container and Git Bash on Windows,
# under bash or zsh (shell/zshrc sets DEVTOOLS_ROOT first; completions are bash-only).

# Resolve the repo root from this file's real location (works through symlinks).
DEVTOOLS_ROOT="${DEVTOOLS_ROOT:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
export DEVTOOLS_ROOT
# Overlay repos (private aliases, scripts): the links in $DEVTOOLS_ROOT/overlays/, loaded in
# name order so a later one overrides an earlier one; the old single $DEVTOOLS_ROOT/overlay
# link still counts. Override the whole list with DEVTOOLS_OVERLAYS=dir:dir. docs/OVERLAY.md.
if [ -z "$DEVTOOLS_OVERLAYS" ]; then
  DEVTOOLS_OVERLAYS="$( { find "$DEVTOOLS_ROOT/overlays" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | sort
                          [ -d "$DEVTOOLS_ROOT/overlay" ] && echo "$DEVTOOLS_ROOT/overlay"; } | paste -sd: - )"
fi
export DEVTOOLS_OVERLAYS
# devtools_overlays: one overlay dir per line. Loop with IFS set to newline so bash and zsh
# both split on lines only:  _ifs=$IFS; IFS=$'\n'; for _o in $(devtools_overlays); do ...; done; IFS=$_ifs
devtools_overlays() { printf '%s\n' "$DEVTOOLS_OVERLAYS" | tr ':' '\n' | sed '/^$/d'; }

# Append-once PATH helper (prepend so repo tools win over system copies).
_path_prepend() { [ -d "$1" ] && case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH";; esac; }

_path_prepend "$HOME/.local/bin"                       # uv, pipx, user installs
_path_prepend "${KREW_ROOT:-$HOME/.krew}/bin"          # kubectl krew plugins
_path_prepend "$HOME/.cargo/bin"
_path_prepend "$DEVTOOLS_ROOT/bin"
_ifs=$IFS; IFS=$'\n'
for _o in $(devtools_overlays); do _path_prepend "$_o/bin"; done   # overlay scripts win; last overlay first
IFS=$_ifs; unset _o _ifs
export PATH

# Container engine used by aliases (override in the overlay or ~/.bashrc.local: DOCKER=podman).
export DOCKER="${DOCKER:-docker}"

# ls: make "other-writable" dirs readable on dark terminals (WSL /mnt/c).
export LS_COLORS="${LS_COLORS}:ow=01;36;40"

# ssh-agent via keychain, only where it exists. The agent starts empty: keys join it on first
# use through "AddKeysToAgent yes" in ~/.ssh/config, so login never asks for a passphrase.
# To preload keys, list their file names (in ~/.ssh) in ~/.keychain_default_keys.
if command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --agents ssh --quiet $(cat ~/.keychain_default_keys 2>/dev/null) 2>/dev/null)"
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

# --- update check: offer to sync when the origin has new commits (see sync.sh) -------
# Runs in interactive shells only, and only for local-path origins (WSL clones of the
# Windows hub: one `git ls-remote` over /mnt/c, ~70 ms per repo, never the network).
#   DEVTOOLS_UPDATE_CHECK=prompt (default, y/N with a 10 s timeout) | hint | off
# Saying no is remembered for those commits: later shells print a one-line hint instead.
_devtools_behind() {   # prints " name@sha" if origin's HEAD is not in this clone's history
  _d="$1"
  [ -d "$_d/.git" ] || return 0
  case "$(git -C "$_d" remote get-url origin 2>/dev/null)" in /*|file://*) ;; *) return 0;; esac
  _r="$(git -C "$_d" ls-remote origin HEAD 2>/dev/null | cut -f1)"
  [ -n "$_r" ] && [ "$_r" != "$(git -C "$_d" rev-parse HEAD 2>/dev/null)" ] || return 0
  git -C "$_d" merge-base --is-ancestor "$_r" HEAD 2>/dev/null && return 0   # we are only ahead
  printf ' %s@%s' "$(basename "$(cd "$_d" && pwd -P)")" "$_r"
}
if [ -t 0 ] && [ -t 1 ] && [ "${DEVTOOLS_UPDATE_CHECK:-prompt}" != off ] && command -v git >/dev/null 2>&1; then
  _upd="$(_devtools_behind "$DEVTOOLS_ROOT"; _ifs=$IFS; IFS=$'\n'; for _o in $(devtools_overlays); do _devtools_behind "$_o"; done)"
  if [ -n "$_upd" ]; then
    _names="$(echo "$_upd" | tr ' ' '\n' | sed '/^$/d; s/@.*//' | tr '\n' ' ')"   # no word-splitting: zsh-safe
    _seen="${XDG_CACHE_HOME:-$HOME/.cache}/devtools/update-declined"
    if [ "${DEVTOOLS_UPDATE_CHECK:-prompt}" = hint ] || [ "$(cat "$_seen" 2>/dev/null)" = "$_upd" ]; then
      echo "devtools: update available (${_names% }) - run 'devtools-sync'"
    else
      _msg="devtools: update available (${_names% }) - sync now? [y/N] "
      _ans=
      if [ -n "$ZSH_VERSION" ]; then read -t 10 -k 1 "_ans?$_msg"; else read -r -t 10 -n 1 -p "$_msg" _ans; fi
      echo
      case "$_ans" in
        y|Y) "$DEVTOOLS_ROOT/sync.sh" && echo "devtools: updated - open a new shell (or: exec ${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}) to load it" ;;
        *) mkdir -p "${_seen%/*}" && printf '%s' "$_upd" > "$_seen" ;;
      esac
    fi
  fi
  unset _upd _names _seen _msg _ans
fi
unset -f _devtools_behind; unset _d _r
