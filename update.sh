#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SOURCE_DIR/scripts/lib.sh"

if [[ $# -ne 1 ]]; then
  dotfiles_print_profile_usage 'bash ./update.sh'
  exit 2
fi

PROFILE="$1"
if ! PLATFORM="$(dotfiles_detect_platform)"; then
  echo "Unsupported platform."
  exit 1
fi

if ! dotfiles_validate_profile "$PLATFORM" "$PROFILE"; then
  dotfiles_print_profile_usage 'bash ./update.sh' >&2
  exit 1
fi

dotfiles_require_supported_os "$PLATFORM"
MISE_ENV_VALUE="$(dotfiles_mise_env "$PLATFORM" "$PROFILE")"

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

  echo "Upgrading managed runtimes/tools within configured version ranges..."
  (
    cd "$SOURCE_DIR"
    "$MISE_BIN" upgrade
  )
else
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

  echo "Upgrading managed runtimes/tools within configured version ranges..."
  (
    cd "$SOURCE_DIR"
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" upgrade
  )
fi

echo "Running health checks..."
if [[ "$PLATFORM" == "linux" ]]; then
  (
    cd "$SOURCE_DIR"
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" doctor
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap status --missing
  )
else
  (
    cd "$SOURCE_DIR"
    "$MISE_BIN" doctor
    "$MISE_BIN" bootstrap status --missing
  )

  brew bundle check --file="$SOURCE_DIR/homebrew/Brewfile"
  HOMEBREW_PROFILE_FILE="$SOURCE_DIR/homebrew/Brewfile.$PROFILE"
  if [[ -f "$HOMEBREW_PROFILE_FILE" ]]; then
    brew bundle check --file="$HOMEBREW_PROFILE_FILE"
  fi
  unset HOMEBREW_PROFILE_FILE
fi

CHEZMOI_BIN="$(command -v chezmoi || true)"
if [[ -z "$CHEZMOI_BIN" || ! -x "$CHEZMOI_BIN" ]]; then
  echo "chezmoi is unavailable after bootstrap."
  exit 1
fi

CHEZMOI_DIFF="$("$CHEZMOI_BIN" --source "$SOURCE_DIR" diff)"
if [[ -n "$CHEZMOI_DIFF" ]]; then
  echo "chezmoi reports unapplied differences:"
  printf '%s\n' "$CHEZMOI_DIFF"
  exit 1
fi
unset CHEZMOI_DIFF

echo "Update completed successfully for $PLATFORM with profile $PROFILE."
echo "Restart the shell to pick up any runtime or shell changes: exec zsh -l"
