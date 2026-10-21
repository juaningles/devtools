#!/bin/bash
# install.sh - link this repo as a devtools overlay in WSL / Linux. Boilerplate from devtools
# templates/overlay; refresh it with devtools-new-overlay --update <this folder>.
#   ~/<overlay>/install.sh                          # devtools at ~/devtools
#   install.sh --from /mnt/<drive>/.../<overlay>    # clone to ~/<overlay> first
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
if [ "${1:-}" = "--from" ]; then
  DEST="$HOME/$(basename "$2")"
  if [ -d "$DEST/.git" ]; then git -C "$DEST" pull --ff-only; else git clone "$2" "$DEST"; fi
  ROOT="$DEST"
fi
DEVTOOLS="${DEVTOOLS_ROOT:-$HOME/devtools}"
[ -x "$DEVTOOLS/install.sh" ] || { echo "devtools not found at $DEVTOOLS (install it first, or set DEVTOOLS_ROOT)" >&2; exit 1; }
git -C "$ROOT" config pull.ff only
"$DEVTOOLS/install.sh" --overlay "$ROOT"
