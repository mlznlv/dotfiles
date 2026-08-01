#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <install|upgrade|check> <profile>" >&2
  exit 2
fi

ACTION="$1"
PROFILE="$2"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_FILE="$SOURCE_DIR/homebrew/Brewfile.$PROFILE"
PROFILE_FILE="${DOTFILES_PROFILE_BREWFILE:-$DEFAULT_FILE}"
EXTRA_FILE="${DOTFILES_EXTRA_BREWFILE:-}"

apply_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "Brewfile not found: $file" >&2; exit 1; }

  case "$ACTION" in
    install) brew bundle install --no-upgrade --file="$file" ;;
    upgrade) brew bundle upgrade --file="$file" ;;
    check) brew bundle check --file="$file" ;;
    *) echo "Unsupported Homebrew action: $ACTION" >&2; exit 2 ;;
  esac
}

apply_file "$PROFILE_FILE"
[[ -z "$EXTRA_FILE" ]] || apply_file "$EXTRA_FILE"
