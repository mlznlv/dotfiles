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
PLATFORM="$(dotfiles_detect_platform)" || exit 1
dotfiles_validate_profile "$PLATFORM" "$PROFILE" || exit 1
dotfiles_require_supported_os "$PLATFORM"
MISE_ENV_VALUE="$(dotfiles_mise_env "$PLATFORM" "$PROFILE")"

if [[ "${DOTFILES_UPDATE_AFTER_PULL:-0}" != "1" ]]; then
  if [[ -n "$(git -C "$SOURCE_DIR" status --porcelain)" ]]; then
    echo "Dotfiles repository has local changes; refusing to update." >&2
    exit 1
  fi
  git -C "$SOURCE_DIR" pull --ff-only
  exec env \
    DOTFILES_UPDATE_AFTER_PULL=1 \
    DOTFILES_PROFILE_BREWFILE="${DOTFILES_PROFILE_BREWFILE:-}" \
    DOTFILES_EXTRA_BREWFILE="${DOTFILES_EXTRA_BREWFILE:-}" \
    bash "$SOURCE_DIR/update.sh" "$PROFILE"
fi

bash "$SOURCE_DIR/scripts/check.sh"
bash "$SOURCE_DIR/bootstrap.sh" "$PROFILE"

MISE_BIN="$(dotfiles_find_executable mise || true)"
CHEZMOI_BIN="$(dotfiles_find_executable chezmoi || true)"
[[ -n "$MISE_BIN" && -x "$MISE_BIN" ]] || { echo "mise is unavailable." >&2; exit 1; }
[[ -n "$CHEZMOI_BIN" && -x "$CHEZMOI_BIN" ]] || { echo "chezmoi is unavailable." >&2; exit 1; }

dotfiles_enable_mise_shims
"$MISE_BIN" self-update --yes || true
"$CHEZMOI_BIN" upgrade || true

if [[ "$PLATFORM" == "macos" ]]; then
  brew update
  brew bundle upgrade --file="$SOURCE_DIR/homebrew/Brewfile"
  if [[ -f "$SOURCE_DIR/homebrew/Brewfile.$PROFILE" || -n "${DOTFILES_PROFILE_BREWFILE:-}" ]]; then
    bash "$SOURCE_DIR/scripts/homebrew-profile.sh" upgrade "$PROFILE"
  fi
  (
    cd "$SOURCE_DIR"
    "$MISE_BIN" bootstrap repos update --yes
    "$MISE_BIN" upgrade
  )
else
  (
    cd "$SOURCE_DIR"
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap packages upgrade --yes
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" bootstrap repos update --yes
    MISE_ENV="$MISE_ENV_VALUE" "$MISE_BIN" upgrade
  )
fi

"$CHEZMOI_BIN" --source "$SOURCE_DIR" apply
bash "$SOURCE_DIR/scripts/health-check.sh" "$PROFILE"

if [[ -n "$("$CHEZMOI_BIN" --source "$SOURCE_DIR" diff)" ]]; then
  echo "chezmoi reports unapplied differences." >&2
  exit 1
fi

echo "Update completed for $PLATFORM/$PROFILE. Restart with: exec zsh -l"
