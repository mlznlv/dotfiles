#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed."
  exit 1
fi

brew bundle --file="$SOURCE_DIR/Brewfile.common"

chezmoi apply

echo "Dotfiles applied successfully."
