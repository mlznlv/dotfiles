#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: ./bootstrap.sh <profile>"
  echo "  macOS: base, local-dev, remote-client"
  echo "  Linux (Ubuntu/Debian): base, dev-host"
  exit 2
fi

PROFILE="$1"

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

case "$PLATFORM/$PROFILE" in
  macos/base|macos/local-dev|macos/remote-client|linux/base|linux/dev-host)
    ;;
  *)
    echo "Unsupported platform/profile combination: $PLATFORM/$PROFILE"
    echo "Supported profiles:"
    echo "  macOS: base, local-dev, remote-client"
    echo "  Linux (Ubuntu/Debian): base, dev-host"
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to bootstrap the environment."
  exit 1
fi

if [[ "$PLATFORM" == "linux" ]] && ! command -v apt-get >/dev/null 2>&1; then
  echo "Unsupported Linux distribution: apt-get is required."
  echo "This repository currently supports Ubuntu/Debian Linux hosts."
  exit 1
fi

if [[ "$PLATFORM" == "macos" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    else
      if ! xcode-select -p >/dev/null 2>&1; then
        echo "Apple Command Line Tools are required before Homebrew can be installed."
        echo "Run: xcode-select --install"
        exit 1
      fi

      echo "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      else
        echo "Homebrew installation failed: brew executable was not found."
        exit 1
      fi
    fi
  fi

  echo "Applying Homebrew base declarations..."
  brew bundle install --no-upgrade --file="$SOURCE_DIR/homebrew/Brewfile"

  HOMEBREW_PROFILE_FILE="$SOURCE_DIR/homebrew/Brewfile.$PROFILE"
  if [[ -f "$HOMEBREW_PROFILE_FILE" ]]; then
    echo "Applying Homebrew $PROFILE declarations..."
    brew bundle install --no-upgrade --file="$HOMEBREW_PROFILE_FILE"
  fi
  unset HOMEBREW_PROFILE_FILE
fi

MISE_BIN="$(command -v mise || true)"
if [[ -z "$MISE_BIN" ]]; then
  curl -fsSL https://mise.run | sh
  MISE_BIN="$HOME/.local/bin/mise"
fi

if [[ ! -x "$MISE_BIN" ]]; then
  echo "mise installation failed: $MISE_BIN is not executable."
  exit 1
fi

# Project portable platform/profile tool defaults into mise's global conf.d.
# Numeric prefixes make precedence explicit: platform -> profile -> machine-local.
MISE_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mise/conf.d"
mkdir -p "$MISE_CONF_DIR"

sync_mise_fragment() {
  local source="$1"
  local target="$2"

  if [[ -f "$source" ]]; then
    cp "$source" "$target"
  else
    rm -f "$target"
  fi
}

sync_mise_fragment \
  "$SOURCE_DIR/mise/runtime.$PLATFORM.toml" \
  "$MISE_CONF_DIR/10-dotfiles-platform.toml"
sync_mise_fragment \
  "$SOURCE_DIR/mise/runtime.$PLATFORM-$PROFILE.toml" \
  "$MISE_CONF_DIR/20-dotfiles-profile.toml"

unset -f sync_mise_fragment
unset MISE_CONF_DIR

if [[ "$PLATFORM" == "linux" ]]; then
  MISE_ENV_VALUE="linux"
  if [[ "$PROFILE" != "base" ]]; then
    MISE_ENV_VALUE="$MISE_ENV_VALUE,linux-$PROFILE"
  fi

  (
    cd "$SOURCE_DIR"
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap --yes
  )
else
  (
    cd "$SOURCE_DIR"
    "$MISE_BIN" bootstrap --yes
  )
fi

# One-time conservative cleanup for a repository that this dotfiles setup used
# to manage. Never delete a mismatched, modified, or unreadable checkout.
LEGACY_AUTOCOMPLETE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zsh-autocomplete"
if [[ -d "$LEGACY_AUTOCOMPLETE_DIR/.git" ]]; then
  LEGACY_AUTOCOMPLETE_ORIGIN="$(git -C "$LEGACY_AUTOCOMPLETE_DIR" config --get remote.origin.url 2>/dev/null || true)"
  case "$LEGACY_AUTOCOMPLETE_ORIGIN" in
    https://github.com/marlonrichert/zsh-autocomplete|https://github.com/marlonrichert/zsh-autocomplete.git|git@github.com:marlonrichert/zsh-autocomplete.git|ssh://git@github.com/marlonrichert/zsh-autocomplete.git)
      if LEGACY_AUTOCOMPLETE_STATUS="$(git -C "$LEGACY_AUTOCOMPLETE_DIR" status --porcelain 2>/dev/null)"; then
        if [[ -z "$LEGACY_AUTOCOMPLETE_STATUS" ]]; then
          echo "Removing obsolete zsh-autocomplete checkout..."
          rm -rf "$LEGACY_AUTOCOMPLETE_DIR"
        else
          echo "Leaving obsolete zsh-autocomplete checkout because it has local changes:"
          echo "  $LEGACY_AUTOCOMPLETE_DIR"
        fi
      else
        echo "Leaving obsolete zsh-autocomplete checkout because its Git state could not be verified:"
        echo "  $LEGACY_AUTOCOMPLETE_DIR"
      fi
      ;;
  esac
fi
unset LEGACY_AUTOCOMPLETE_DIR LEGACY_AUTOCOMPLETE_ORIGIN LEGACY_AUTOCOMPLETE_STATUS

CHEZMOI_BIN="$(command -v chezmoi || true)"
if [[ -z "$CHEZMOI_BIN" ]]; then
  mkdir -p "$HOME/.local/bin"
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
  CHEZMOI_BIN="$HOME/.local/bin/chezmoi"
fi

if [[ ! -x "$CHEZMOI_BIN" ]]; then
  echo "chezmoi installation failed: $CHEZMOI_BIN is not executable."
  exit 1
fi

"$CHEZMOI_BIN" --source "$SOURCE_DIR" apply

echo "Dotfiles applied successfully for $PLATFORM with profile $PROFILE."
