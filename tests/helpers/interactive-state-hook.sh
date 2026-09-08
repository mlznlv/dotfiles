#!/usr/bin/env bash

set -eu

: "${DOTFILES_PTY_STATE_PATH:?}"
: "${DOTFILES_PTY_STATE_BODY_FILE:?}"
: "${DOTFILES_PTY_IDENTITY_FILE:?}"

replacement="${DOTFILES_PTY_STATE_PATH}.external"
cp "$DOTFILES_PTY_STATE_BODY_FILE" "$replacement"
chmod 600 "$replacement"
mv -f "$replacement" "$DOTFILES_PTY_STATE_PATH"

if stat -f '%d:%i' "$DOTFILES_PTY_STATE_PATH" >/dev/null 2>&1; then
    stat -f '%d:%i' "$DOTFILES_PTY_STATE_PATH" > "$DOTFILES_PTY_IDENTITY_FILE"
else
    stat -c '%d:%i' "$DOTFILES_PTY_STATE_PATH" > "$DOTFILES_PTY_IDENTITY_FILE"
fi
