# venv.sh - backward-compatible entry point for scripts that still do `source venv.sh`
# (e.g. a project's init.sh). Must be SOURCED, not executed.
# Creates/activates a per-distro uv virtualenv at .venv/<distro>:
#   - pyproject.toml present  -> uv sync into it
#   - else                     -> uv venv, then uv pip install -r requirements.txt if present
# New code should call the `activate` function from shell/aliases.sh, which is the same logic.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "venv.sh must be sourced:  source venv.sh" >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh   (or winget install astral-sh.uv)" >&2
  return 1
fi

_venv_dir=".venv/${WSL_DISTRO_NAME:-$(uname -s)}"
if [ -f pyproject.toml ]; then
  UV_PROJECT_ENVIRONMENT="$_venv_dir" uv sync || return 1
else
  [ -d "$_venv_dir" ] || uv venv "$_venv_dir" || return 1
  if [ -f requirements.txt ]; then VIRTUAL_ENV="$(cd "$_venv_dir" && pwd)" uv pip install -r requirements.txt || return 1; fi
fi
# shellcheck disable=SC1090,SC1091
if [ -f "$_venv_dir/bin/activate" ]; then source "$_venv_dir/bin/activate"; else source "$_venv_dir/Scripts/activate"; fi
alias workdir="cd $(pwd)"
unset _venv_dir
