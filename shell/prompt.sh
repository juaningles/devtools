# shell/prompt.sh - the coloured two-line prompt, extracted once from the old
# bashrc / bash_aliases (where it was duplicated verbatim).
#   HH:MM:SS user@host:/path (git-branch)
#   $

[ -n "$BASH_VERSION" ] || return 0

# Colour if the terminal can do it.
_color_prompt=
case "$TERM" in xterm-color|*-256color|xterm*|screen*|tmux*) _color_prompt=yes;; esac
if [ -x /usr/bin/tput ] && tput setaf 1 >/dev/null 2>&1; then _color_prompt=yes; fi

# Inside the devnode container? (old check parsed redis pid namespaces; this is
# the conventional test and gives the same answer in devnode)
if [ -f /.dockerenv ] || grep -qsE 'docker|containerd|kubepods' /proc/1/cgroup 2>/dev/null; then
  export IN_MATRIX=yes
else
  unset IN_MATRIX
fi

# git branch for the prompt: prefer __git_ps1 when available.
for _gp in /etc/bash_completion.d/git-prompt /usr/share/git-core/contrib/completion/git-prompt.sh \
           /usr/lib/git-core/git-sh-prompt /mingw64/share/git/completion/git-prompt.sh; do
  # shellcheck disable=SC1090
  [ -f "$_gp" ] && { source "$_gp"; break; }
done
unset _gp
if declare -F __git_ps1 >/dev/null; then
  export GIT_PS1_SHOWDIRTYSTATE=yes GIT_PS1_SHOWUNTRACKEDFILES=yes GIT_PS1_SHOWSTASHSTATE=yes \
         GIT_PS1_SHOWUPSTREAM=yes GIT_PS1_SHOWCONFLICTSTATE=yes GIT_PS1_SHOWCOLORHINTS=yes
  _ps_branch='$(__git_ps1 " (%s)")'
else
  git_branch() { git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'; }
  _ps_branch='$(b=$(git_branch); [ -n "$b" ] && echo " ($b)")'
fi

if [ "$_color_prompt" = yes ]; then
  _host='\h'; [ -n "$IN_MATRIX" ] && _host='devnode'
  PS1="\[\033[01;36m\]\t\[\033[00m\] \[\033[01;32m\]\u@${_host}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\[\033[00;33m\]${_ps_branch}\[\033[00m\]\n \$ "
  PS2='\[\033[01;36m\]> \[\033[00m\]'
  unset _host
else
  PS1="${debian_chroot:+($debian_chroot)}\u@\h:\w${_ps_branch}\n\$ "
fi

# Terminal title.
case "$TERM" in xterm*|rxvt*) PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1";; esac

unset _color_prompt _ps_branch
