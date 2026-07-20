#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${1:-base}"

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
    echo "  Linux: base, dev-host"
    exit 1
    ;;
esac

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

# Install a machine-profile runtime fragment into mise's global conf.d.
# This keeps full development workstations useful outside project directories
# without forcing heavyweight runtimes onto lightweight remote clients.
MISE_PROFILE_SOURCE="$SOURCE_DIR/mise/runtime.$PLATFORM-$PROFILE.toml"
MISE_PROFILE_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/mise/conf.d/20-dotfiles-profile.toml"
mkdir -p "$(dirname "$MISE_PROFILE_TARGET")"
if [[ -f "$MISE_PROFILE_SOURCE" ]]; then
  cp "$MISE_PROFILE_SOURCE" "$MISE_PROFILE_TARGET"
else
  rm -f "$MISE_PROFILE_TARGET"
fi

MISE_ENV_VALUE="$PLATFORM"
if [[ "$PROFILE" != "base" ]]; then
  MISE_ENV_VALUE="$MISE_ENV_VALUE,$PLATFORM-$PROFILE"
fi

(
  cd "$SOURCE_DIR"
  MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap --yes
)

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
