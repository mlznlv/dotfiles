#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$SOURCE_DIR/scripts/lib.sh"

if [[ $# -ne 1 ]]; then
  dotfiles_print_profile_usage './scripts/health-check.sh'
  exit 2
fi

PROFILE="$1"
PLATFORM="$(dotfiles_detect_platform)" || exit 1
dotfiles_validate_profile "$PLATFORM" "$PROFILE" || exit 1

failed=0
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '[ok] %s\n' "$name"
  else
    printf '[fail] %s\n' "$name" >&2
    failed=1
  fi
}
warn() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '[ok] %s\n' "$name"
  else
    printf '[warn] %s\n' "$name" >&2
  fi
}

check git command -v git
check mise command -v mise
check chezmoi command -v chezmoi
check zsh command -v zsh

if [[ "$PLATFORM" == "macos" ]]; then
  check brew command -v brew
  check ghostty test -d '/Applications/Ghostty.app'

  if [[ "$PROFILE" == "remote-client" || "$PROFILE" == "local-dev" ]]; then
    check vscode test -x '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code'
    check tailscale-app test -d '/Applications/Tailscale.app'
    warn tailscale-cli command -v tailscale
    check remote-ssh grep -Fxq 'ms-vscode-remote.remote-ssh' "$SOURCE_DIR/editor/vscode/extensions.remote-client.txt"
    check dev-containers grep -Fxq 'ms-vscode-remote.remote-containers' "$SOURCE_DIR/editor/vscode/extensions.remote-client.txt"
  fi

  if [[ "$PROFILE" == "local-dev" ]]; then
    check docker-cli command -v docker
    warn docker-engine docker info
    check compose docker compose version
    check node node --version
    check python python --version
    check aws aws --version
    check kubectl kubectl version --client
    check tofu tofu version
    check ansible ansible --version
    check python-extension grep -Fxq 'ms-python.python' "$SOURCE_DIR/editor/vscode/extensions.local-dev.txt"
    check ruff-extension grep -Fxq 'charliermarsh.ruff' "$SOURCE_DIR/editor/vscode/extensions.local-dev.txt"
  fi
fi

if [[ "$PLATFORM" == "linux" && "$PROFILE" == "dev-host" ]]; then
  check sshd command -v sshd
  check tmux command -v tmux
fi

exit "$failed"
