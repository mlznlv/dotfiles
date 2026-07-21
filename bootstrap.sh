#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SOURCE_DIR/scripts/lib.sh"

if [[ $# -ne 1 ]]; then
  dotfiles_print_profile_usage './bootstrap.sh'
  exit 2
fi

PROFILE="$1"
if ! PLATFORM="$(dotfiles_detect_platform)"; then
  echo "Unsupported platform."
  exit 1
fi

if ! dotfiles_validate_profile "$PLATFORM" "$PROFILE"; then
  dotfiles_print_profile_usage './bootstrap.sh' >&2
  exit 1
fi

dotfiles_require_supported_os "$PLATFORM"
MISE_ENV_VALUE="$(dotfiles_mise_env "$PLATFORM" "$PROFILE")"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to bootstrap the environment."
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

MISE_BIN="$(dotfiles_find_executable mise || true)"
if [[ -z "$MISE_BIN" ]]; then
  curl -fsSL https://mise.run | sh
  MISE_BIN="$(dotfiles_find_executable mise || true)"
fi

if [[ -z "$MISE_BIN" || ! -x "$MISE_BIN" ]]; then
  echo "mise installation failed: executable was not found."
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

bash "$SOURCE_DIR/scripts/migrate-legacy.sh"

CHEZMOI_BIN="$(dotfiles_find_executable chezmoi || true)"
if [[ -z "$CHEZMOI_BIN" ]]; then
  mkdir -p "$HOME/.local/bin"
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
  CHEZMOI_BIN="$(dotfiles_find_executable chezmoi || true)"
fi

if [[ -z "$CHEZMOI_BIN" || ! -x "$CHEZMOI_BIN" ]]; then
  echo "chezmoi installation failed: executable was not found."
  exit 1
fi

"$CHEZMOI_BIN" --source "$SOURCE_DIR" apply

echo "Dotfiles applied successfully for $PLATFORM with profile $PROFILE."
