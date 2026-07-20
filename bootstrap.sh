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

case "$PLATFORM/$ROLE" in
  macos/workstation|macos/client|linux/server)
    ;;
  macos/|linux/)
    echo "Usage: ./bootstrap.sh <role>"
    echo "macOS roles: workstation, client"
    echo "Linux roles: server"
    exit 1
    ;;
  *)
    echo "Unsupported platform/role combination: $PLATFORM/$ROLE"
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
    if ! command -v apt-get >/dev/null 2>&1; then
      echo "Unsupported Linux package manager."
      exit 1
    fi

    sudo apt-get update
    xargs sudo apt-get install -y < "$SOURCE_DIR/packages/linux/apt.common"

    ROLE_APT="$SOURCE_DIR/packages/linux/apt.$ROLE"
    if [[ -s "$ROLE_APT" ]]; then
      xargs sudo apt-get install -y < "$ROLE_APT"
    fi

    if ! command -v chezmoi >/dev/null 2>&1; then
      mkdir -p "$HOME/.local/bin"
      sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
      export PATH="$HOME/.local/bin:$PATH"
    fi

    if ! command -v zoxide >/dev/null 2>&1; then
      curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
      export PATH="$HOME/.local/bin:$PATH"
    fi

    ZSH_PLUGIN_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
    mkdir -p "$ZSH_PLUGIN_HOME"

    install_zsh_plugin() {
      local repository="$1"
      local name="$2"

      if [[ ! -d "$ZSH_PLUGIN_HOME/$name/.git" ]]; then
        git clone --depth 1 "https://github.com/$repository.git" "$ZSH_PLUGIN_HOME/$name"
      fi
    }

    install_zsh_plugin "marlonrichert/zsh-autocomplete" "zsh-autocomplete"
    install_zsh_plugin "zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
    install_zsh_plugin "zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting"

    unset -f install_zsh_plugin
    unset ZSH_PLUGIN_HOME
    ;;
esac

case "$ROLE" in
  workstation|server)
    if [[ ! -d "$HOME/.nvm/.git" ]]; then
      git clone --branch v0.39.7 --depth 1         https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
    fi
    ;;
esac

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
printf '%s\n' "$ROLE" > "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/role"

chezmoi apply

echo "Dotfiles applied successfully for $PLATFORM/$ROLE."
