#!/bin/bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required first."
  exit 1
fi

brew bundle --file="$HOME/.local/share/chezmoi/Brewfile.common"

chezmoi apply

echo "Base dotfiles installed."
