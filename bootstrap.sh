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
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap --yes --update
  )
else
  (
    cd "$SOURCE_DIR"
    "$MISE_BIN" bootstrap --yes
  )
fi

# Remove files from the legacy layered Zsh design only when their content still
# exactly matches a known Git blob from the old managed state. This keeps
# migration cleanup safe for modified files and for future users of the repo.
ZSH_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
remove_legacy_zsh_file() {
  local relative_path="$1"
  local expected_blob="$2"
  local target="$ZSH_CONFIG_HOME/$relative_path"
  local actual_blob

  [[ -f "$target" ]] || return 0
  actual_blob="$(git hash-object -- "$target" 2>/dev/null)" || return 0
  [[ "$actual_blob" == "$expected_blob" ]] || return 0

  echo "Removing obsolete managed Zsh file: $target"
  rm -f -- "$target"
}

remove_legacy_zsh_file "features/dev-runtimes.zsh" "8d494c68665ae897443c3ab79d00496d2ca94856"
remove_legacy_zsh_file "platform.zsh" "978ce53b6a36d8be2d1bba1d7842abff87e270be"
remove_legacy_zsh_file "platforms/linux.profile.zsh" "80a62c079b9f58f9fa15d3cfaa9853bf960a0122"
remove_legacy_zsh_file "platforms/linux.zsh" "fb22d7245e1b6974badbeb42a0fa7d7f683dfd96"
remove_legacy_zsh_file "platforms/macos.profile.zsh" "6dfb02526cde08d0598258b868e499bddfaf7606"
remove_legacy_zsh_file "platforms/macos.zsh" "f4e2d4403b26837acbe2efea1cc56d86920f4dbf"
remove_legacy_zsh_file "plugins.zsh" "b31ef293b5333a3e1e1d76c97e1c36c36fcc86ee"
remove_legacy_zsh_file "role.zsh" "40325c1d133643f1dc9d2e337deaac8c546a34d5"
remove_legacy_zsh_file "roles/client.zsh" "ecc55769b451c755cc5f2a9a687c80f73e66fea8"
remove_legacy_zsh_file "roles/server.zsh" "8da9200e43c83ec6592e3c3926876bde034eccb5"
remove_legacy_zsh_file "roles/workstation.zsh" "8910875dc18f0c7edb0954e45e847c3bb90c2284"
remove_legacy_zsh_file "tools.zsh" "7701aad0ca8afae813bb9d84357e7505f4542e80"

rmdir \
  "$ZSH_CONFIG_HOME/features" \
  "$ZSH_CONFIG_HOME/platforms" \
  "$ZSH_CONFIG_HOME/roles" \
  2>/dev/null || true
unset -f remove_legacy_zsh_file
unset ZSH_CONFIG_HOME

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
