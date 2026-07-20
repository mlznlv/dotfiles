#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISE_CONFIG_DIR="$SOURCE_DIR/mise"
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
  echo "curl is required to bootstrap mise and chezmoi."
  exit 1
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

MISE_ENV_VALUE="$PLATFORM"
if [[ "$PROFILE" != "base" ]]; then
  MISE_ENV_VALUE="$MISE_ENV_VALUE,$PLATFORM-$PROFILE"
fi

(
  cd "$SOURCE_DIR"
  MISE_CONFIG_DIR="$MISE_CONFIG_DIR" \
    MISE_ENV="$MISE_ENV_VALUE" \
    "$MISE_BIN" bootstrap --yes
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
