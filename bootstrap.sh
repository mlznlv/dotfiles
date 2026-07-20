#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLE="${1:-}"

case "$(uname -s)" in
  Darwin)
    PLATFORM="macos"
    ;;
  Linux)
    PLATFORM="linux"
    ;;
  *)
    echo "Unsupported platform."
    exit 1
    ;;
esac

case "$ROLE" in
  workstation|client)
    ;;
  "")
    echo "Usage: ./bootstrap.sh <workstation|client>"
    exit 1
    ;;
  *)
    echo "Unsupported role: $ROLE"
    exit 1
    ;;
esac

case "$PLATFORM" in
  macos)
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew is not installed."
      exit 1
    fi

    brew bundle --file="$SOURCE_DIR/packages/macos/Brewfile.common"

    ROLE_BREWFILE="$SOURCE_DIR/packages/macos/Brewfile.$ROLE"
    if [[ -f "$ROLE_BREWFILE" ]]; then
      brew bundle --file="$ROLE_BREWFILE"
    fi
    ;;
  linux)
    echo "Linux package bootstrap is not implemented yet."
    exit 1
    ;;
esac

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
printf '%s\n' "$ROLE" > "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/role"

chezmoi apply

echo "Dotfiles applied successfully for $PLATFORM/$ROLE."
