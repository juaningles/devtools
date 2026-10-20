#!/bin/bash
# sync.sh - keep this clone (and every overlay that is a git clone) in step with
# its origin (the Windows clone by default).
#   devtools-sync          pull --ff-only, then push local commits back if any
#   devtools-sync --status just show ahead/behind
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
STATUS_ONLY=no; [ "${1:-}" = "--status" ] && STATUS_ONLY=yes

sync_repo() {
  local dir="$1" branch behind ahead
  cd "$dir"
  if [ -n "$(git status --porcelain)" ]; then
    echo "sync: uncommitted changes in $dir - commit or stash them first:"; git status --short; return 1
  fi
  git fetch --quiet origin
  branch=$(git rev-parse --abbrev-ref HEAD)
  read -r behind ahead < <(git rev-list --left-right --count "origin/$branch...$branch")
  echo "sync: $dir  behind=$behind ahead=$ahead  (origin: $(git remote get-url origin))"
  [ "$STATUS_ONLY" = yes ] && return 0
  [ "$behind" -gt 0 ] && git pull --ff-only
  if [ "$ahead" -gt 0 ]; then
    # origin is a normal checkout with receive.denyCurrentBranch=updateInstead, so this works
    git push origin "$branch" && echo "sync: pushed $ahead commit(s) to origin"
  fi
  chmod +x "$dir"/bin/* 2>/dev/null || true
}

sync_repo "$ROOT"
# overlays, same order as the shell loads them (overlays/* by name, then the old single link)
for ov in "$ROOT"/overlays/* "$ROOT/overlay"; do
  [ -e "$ov/.git" ] || continue
  sync_repo "$(readlink -f "$ov")"
done
echo "sync: ok"
