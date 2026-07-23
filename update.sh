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

echo "Checking repository before applying changes..."
bash "$SOURCE_DIR/scripts/check.sh"

MISE_BIN="$(dotfiles_find_executable mise || true)"
if [[ -z "$MISE_BIN" ]]; then
  echo "mise is missing; bootstrapping the selected profile first..."
  bash "$SOURCE_DIR/bootstrap.sh" "$PROFILE"
  MISE_BIN="$(dotfiles_find_executable mise || true)"
fi

if [[ -z "$MISE_BIN" || ! -x "$MISE_BIN" ]]; then
  echo "mise is unavailable after bootstrap."
  exit 1
fi

dotfiles_enable_mise_shims

echo "Updating mise..."
if ! "$MISE_BIN" self-update --yes; then
  echo "mise self-update was unavailable or failed; continuing with the installed version."
fi

# Re-resolve the executable after self-update and keep shims available to this
# non-interactive script and any child processes it starts.
MISE_BIN="$(dotfiles_find_executable mise || true)"
if [[ -z "$MISE_BIN" || ! -x "$MISE_BIN" ]]; then
  echo "mise is unavailable after self-update."
  exit 1
fi
dotfiles_enable_mise_shims

# Apply the newest declarations first. On macOS bootstrap uses the real Homebrew
# CLI with --no-upgrade, so this only installs newly declared dependencies.
echo "Applying latest profile declarations..."
bash "$SOURCE_DIR/bootstrap.sh" "$PROFILE"

# Validate config loading separately so a missing/stale config path is reported at
# a precise stage instead of surfacing later as an unrelated upgrade failure.
echo "Validating mise configuration..."
set +e
if [[ "$PLATFORM" == "linux" ]]; then
  MISE_CONFIG_CHECK="$(
    cd "$SOURCE_DIR" &&
      MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" config ls 2>&1
  )"
  MISE_CONFIG_STATUS=$?
else
  MISE_CONFIG_CHECK="$(
    cd "$SOURCE_DIR" &&
      "$MISE_BIN" config ls 2>&1
  )"
  MISE_CONFIG_STATUS=$?
fi
set -e
if (( MISE_CONFIG_STATUS != 0 )); then
  echo "mise configuration failed to load:" >&2
  printf '%s\n' "$MISE_CONFIG_CHECK" >&2
  echo "Inspect active MISE_* environment variables and ~/.config/mise before retrying." >&2
  exit "$MISE_CONFIG_STATUS"
fi
unset MISE_CONFIG_CHECK MISE_CONFIG_STATUS

CHEZMOI_BIN="$(dotfiles_find_executable chezmoi || true)"
if [[ -z "$CHEZMOI_BIN" || ! -x "$CHEZMOI_BIN" ]]; then
  echo "chezmoi is unavailable after bootstrap."
  exit 1
fi

echo "Updating chezmoi..."
if ! "$CHEZMOI_BIN" upgrade; then
  echo "chezmoi upgrade was unavailable or failed; continuing with the installed version."
fi

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

echo "Running non-interactive health checks..."
if [[ "$PLATFORM" == "linux" ]]; then
  (
    cd "$SOURCE_DIR"
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" current
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap status --missing
  )
else
  (
    cd "$SOURCE_DIR"
    "$MISE_BIN" current
    "$MISE_BIN" bootstrap status --missing
  )

  brew bundle check --file="$SOURCE_DIR/homebrew/Brewfile"
  HOMEBREW_PROFILE_FILE="$SOURCE_DIR/homebrew/Brewfile.$PROFILE"
  if [[ -f "$HOMEBREW_PROFILE_FILE" ]]; then
    brew bundle check --file="$HOMEBREW_PROFILE_FILE"
  fi
  unset HOMEBREW_PROFILE_FILE
fi

CHEZMOI_DIFF="$("$CHEZMOI_BIN" --source "$SOURCE_DIR" diff)"
if [[ -n "$CHEZMOI_DIFF" ]]; then
  echo "chezmoi reports unapplied differences:"
  printf '%s\n' "$CHEZMOI_DIFF"
  exit 1
fi
unset CHEZMOI_DIFF

echo "Update completed successfully for $PLATFORM with profile $PROFILE."
echo "Restart the shell to pick up runtime/shell changes: exec zsh -l"
echo "After restart, use 'mise doctor' for interactive shell diagnostics."
