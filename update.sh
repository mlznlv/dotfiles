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

# Pull first, then restart this script so the remainder always runs the newest
# update logic from the repository.
if [[ "${DOTFILES_UPDATE_AFTER_PULL:-0}" != "1" ]]; then
  if [[ -n "$(git -C "$SOURCE_DIR" status --porcelain)" ]]; then
    echo "Dotfiles repository has local changes; refusing to update over them."
    echo "Review them first: git -C \"$SOURCE_DIR\" status"
    exit 1
  fi

  echo "Updating dotfiles repository..."
  git -C "$SOURCE_DIR" pull --ff-only
  exec env DOTFILES_UPDATE_AFTER_PULL=1 bash "$SOURCE_DIR/update.sh" "$PROFILE"
fi

MISE_BIN="$(command -v mise || true)"
if [[ -z "$MISE_BIN" ]]; then
  echo "mise is missing; bootstrapping the selected profile first..."
  bash "$SOURCE_DIR/bootstrap.sh" "$PROFILE"
  MISE_BIN="$(command -v mise || true)"
fi

if [[ -z "$MISE_BIN" || ! -x "$MISE_BIN" ]]; then
  echo "mise is unavailable after bootstrap."
  exit 1
fi

echo "Updating mise..."
if ! "$MISE_BIN" self-update --yes; then
  echo "mise self-update was unavailable or failed; continuing with the installed version."
fi

# Apply the newest declarations first. On macOS bootstrap uses the real Homebrew
# CLI with --no-upgrade, so this only installs newly declared dependencies.
echo "Applying latest profile declarations..."
bash "$SOURCE_DIR/bootstrap.sh" "$PROFILE"

if [[ "$PLATFORM" == "macos" ]]; then
  echo "Updating Homebrew metadata..."
  brew update

  echo "Upgrading Homebrew base declarations..."
  brew bundle upgrade --file="$SOURCE_DIR/homebrew/Brewfile"

  HOMEBREW_PROFILE_FILE="$SOURCE_DIR/homebrew/Brewfile.$PROFILE"
  if [[ -f "$HOMEBREW_PROFILE_FILE" ]]; then
    echo "Upgrading Homebrew $PROFILE declarations..."
    brew bundle upgrade --file="$HOMEBREW_PROFILE_FILE"
  fi
  unset HOMEBREW_PROFILE_FILE

  echo "Updating managed repositories..."
  (
    cd "$SOURCE_DIR"
    "$MISE_BIN" bootstrap repos update --yes
  )

  echo "Upgrading managed runtimes within configured version ranges..."
  (
    cd "$SOURCE_DIR"
    "$MISE_BIN" upgrade
  )
else
  MISE_ENV_VALUE="linux"
  if [[ "$PROFILE" != "base" ]]; then
    MISE_ENV_VALUE="$MISE_ENV_VALUE,linux-$PROFILE"
  fi

  echo "Upgrading managed Linux system packages..."
  (
    cd "$SOURCE_DIR"
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap packages upgrade --yes
  )

  echo "Updating managed repositories..."
  (
    cd "$SOURCE_DIR"
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap repos update --yes
  )

  echo "Upgrading managed runtimes within configured version ranges..."
  (
    cd "$SOURCE_DIR"
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" upgrade
  )
fi

echo "Running health checks..."
"$MISE_BIN" doctor

if [[ "$PLATFORM" == "macos" ]]; then
  brew bundle check --file="$SOURCE_DIR/homebrew/Brewfile"
  HOMEBREW_PROFILE_FILE="$SOURCE_DIR/homebrew/Brewfile.$PROFILE"
  if [[ -f "$HOMEBREW_PROFILE_FILE" ]]; then
    brew bundle check --file="$HOMEBREW_PROFILE_FILE"
  fi
  unset HOMEBREW_PROFILE_FILE
fi

CHEZMOI_BIN="$(command -v chezmoi || true)"
if [[ -n "$CHEZMOI_BIN" ]]; then
  if [[ -n "$("$CHEZMOI_BIN" --source "$SOURCE_DIR" diff)" ]]; then
    echo "chezmoi reports unapplied differences:"
    "$CHEZMOI_BIN" --source "$SOURCE_DIR" diff
    exit 1
  fi
fi

echo "Update completed successfully for $PLATFORM with profile $PROFILE."
echo "Restart the shell to pick up any runtime or shell changes: exec zsh -l"
