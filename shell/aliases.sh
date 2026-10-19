# shell/aliases.sh - the single alias list for bash (WSL, Linux, Git Bash).
#
# FORMAT RULES (tools/gen-shims.ps1 parses this file to build cmd.exe shims
# and PowerShell functions, so keep to these two shapes):
#
#   alias name='command words'            #win   -> shim appends the caller's args
#   name() { command "$@" more; }         #win   -> "$@" marks where args go
#
# Only lines ending in "#win" are turned into Windows shims. Anything that
# needs bash (pipes, $(...), ~, env vars, functions with logic) is left out
# of the Windows set on purpose.
#
# Work/customer-specific aliases do NOT belong here: put them in an overlay
# repo (docs/OVERLAY.md). This file is sourced by bash AND zsh: keep it portable.

# --- kubectl -----------------------------------------------------------------
alias k='kubectl'                                                   #win
alias kg='kubectl get'                                              #win
alias kd='kubectl describe'                                         #win
alias kl='kubectl get pods,jobs,cronjobs -o wide'                   #win
alias klogs='kubectl logs --follow'                                 #win
alias kx='kubectl exec -it'                                         #win
alias kpods='kubectl get pods -o wide'                              #win
alias knodes='kubectl get nodes -o wide'                            #win
alias kw='watch kubectl'
alias kpw='kubectl get pod --watch'                                 #win
kbash() { kubectl exec -it "$@" -- /bin/bash; }                     #win
ksh()   { kubectl exec -it "$@" -- /bin/sh; }                       #win
kmux()  { kubectl exec -it "$@" -- /usr/bin/tmux -u new-session -A -s "$USER"; }
kmux2() { kubectl exec -it "$@" -- /usr/bin/tmux -u new-session -A -s "${USER}2"; }
alias kssh='kbash'

# contexts / namespaces
alias k8l='kubectl config get-contexts'                             #win
alias k8s='kubectl config use-context'                              #win
alias k8n='kubectl config set-context --current --namespace'        #win
alias kc='kubectl config get-contexts -o name'                      #win
kcfor() { kubectl config get-contexts -o name | xargs -I{} "$@"; }

# cronjob helpers live in bin/ (cron2cli, cron2job, cron-keepalive, fixpod.sh)
alias keepalive='cron-keepalive'

# --- containers (docker or podman; $DOCKER is set in env.sh) ----------------
alias di='$DOCKER images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}"'
alias dive='$DOCKER run -ti --rm -v /var/run/docker.sock:/var/run/docker.sock docker.io/wagoodman/dive'
alias drun='$DOCKER run -it --net=host'       # fix for docker connection issues on jump servers
alias dbash='$DOCKER exec -it devnode'
alias dacr-login='az acr login -n'
pacr-login() {
  local acr="$1" token
  [ -z "$acr" ] && { echo "usage: pacr-login <acr-name>"; return 1; }
  token=$(az acr login -n "$acr" --expose-token --output tsv --query accessToken) || return 1
  podman login "$acr.azurecr.io" -u 00000000-0000-0000-0000-000000000000 -p "$token"
}

# --- python (uv) --------------------------------------------------------------
# Per-distro venv so a repo shared between Windows and several WSL distros
# does not fight over one .venv. Replaces the old venv.sh.
activate() { source "$DEVTOOLS_ROOT/bin/venv.sh"; }   # logic lives in bin/venv.sh (also sourceable directly)
alias noisy='PYTHONUNBUFFERED=1 LOG_LEVEL=DEBUG pytest --log-cli-level=DEBUG -xvs'
alias quiet='pytest -q --tb=no'
alias med='LOG_LEVEL=WARN pytest -xvs'

# --- misc ---------------------------------------------------------------------
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias randkey='cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c${1:-64}; echo'
alias asum="awk '{sum+=\$0} END{print sum}'"
alias hilite='grep --color=always -e "^" -e'
alias squelch='grep -P "(^(\e\[[^\[]*)|^(\[))\[[PI].*"'
alias s1='sudo $(fc -ln -1)'
alias cdcode='cd ~/code'
alias nogitps1="export PS1='\[\e]0;\u@\h: \w\a\]\033[01;36m\]\t\033[01;32m\] \u@\033[01;32m\]\h\033[01;32m\]:\[\033[01;34m\]\w\[\033[00m\] \033[00;33m\]\[\033[00m\]\n$ '"
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# --- devtools self-management -------------------------------------------------
alias devtools-sync='"$DEVTOOLS_ROOT/sync.sh"'
alias devtools-shims='powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$DEVTOOLS_ROOT/tools/gen-shims.ps1" 2>/dev/null || echo "$DEVTOOLS_ROOT/tools/gen-shims.ps1")"'
