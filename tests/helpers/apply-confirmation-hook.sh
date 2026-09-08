#!/usr/bin/env bash

set -u

stat_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

case ${DOTFILES_CONFIRM_HOOK_MODE:-} in
    write-target)
        printf '%s\n' 'changed while confirmation was pending' > "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    remove-prerequisite)
        chmod -x "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    break-artifact)
        rm -f -- "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    delete-selection)
        rm -f -- "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    corrupt-selection)
        printf '%s\n' 'not canonical selection state' > "$DOTFILES_CONFIRM_HOOK_TARGET"
        chmod 600 "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    change-selection)
        printf '%s\n' \
            'schema = 1' \
            '' \
            '[selection]' \
            'modules = ["shell.zsh"]' \
            'additional_modules = []' > "$DOTFILES_CONFIRM_HOOK_TARGET"
        chmod 600 "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    change-equivalent-selection)
        printf '%s\n' \
            'schema = 1' \
            '' \
            '[selection]' \
            'modules = ["shell.zsh", "shell.zsh.autosuggestions", "prompt.starship"]' \
            'additional_modules = []' > "$DOTFILES_CONFIRM_HOOK_TARGET"
        chmod 600 "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    replace-identical-selection)
        replacement="${DOTFILES_CONFIRM_HOOK_TARGET}.replacement"
        cp -- "$DOTFILES_CONFIRM_HOOK_TARGET" "$replacement"
        chmod 600 "$replacement"
        mv -f -- "$replacement" "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    symlink-selection)
        rm -f -- "$DOTFILES_CONFIRM_HOOK_TARGET"
        ln -s /dev/null "$DOTFILES_CONFIRM_HOOK_TARGET"
        ;;
    term)
        kill -TERM "-${DOTFILES_PTY_CHILD_PID}"
        ;;
    inspect-private)
        for private_path in "${TMPDIR%/}"/dotfiles-apply.*; do
            [ -d "$private_path" ] || continue
            find "$private_path" -type d -print | while IFS= read -r path; do
                printf 'directory %s\n' "$(stat_mode "$path")"
            done
            find "$private_path" -type f -print | while IFS= read -r path; do
                printf 'file %s\n' "$(stat_mode "$path")"
            done
        done > "$DOTFILES_CONFIRM_HOOK_LOG"
        ;;
    *)
        printf 'error: unknown confirmation hook mode\n' >&2
        exit 2
        ;;
esac
