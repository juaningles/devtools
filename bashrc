# devtools/bashrc - symlinked to ~/.bashrc by install.sh (and sourced by Git
# Bash's ~/.bashrc on Windows). Stock Debian defaults first, then the repo's
# shell/*.sh, then the overlay's shell/*.sh (docs/OVERLAY.md), then ~/.bashrc.local.

case $- in *i*) ;; *) return;; esac   # interactive shells only

HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize
HISTSIZE=5000
HISTFILESIZE=10000

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then debian_chroot=$(cat /etc/debian_chroot); fi

if [ -x /usr/bin/dircolors ]; then
  if test -r ~/.dircolors; then eval "$(dircolors -b ~/.dircolors)"; else eval "$(dircolors -b)"; fi
  alias ls='ls --color=auto' grep='grep --color=auto' fgrep='fgrep --color=auto' egrep='egrep --color=auto'
fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then . /etc/bash_completion; fi
fi

# --- devtools ------------------------------------------------------------------
DEVTOOLS_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export DEVTOOLS_ROOT
. "$DEVTOOLS_ROOT/shell/env.sh"        # PATH lives here and only here
. "$DEVTOOLS_ROOT/shell/prompt.sh"
. "$DEVTOOLS_ROOT/shell/aliases.sh"
for _f in "$DEVTOOLS_OVERLAY"/shell/*.sh; do [ -r "$_f" ] && . "$_f"; done; unset _f
[ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"   # per-machine overrides
