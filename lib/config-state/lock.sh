# Source-only lock identity, signal coordination, durability, and owned cleanup.

dotfiles_config_flush() {
    local kind=$1
    local path=$2

    dotfiles_config_hook "${kind}_FLUSH" || return 4
    if [ -n "${DOTFILES_CONFIG_PRIVATE_ROOT_ACTIVE:-}" ] && [ "${DOTFILES_CONFIG_TEST_SKIP_SYNC:-0}" = 1 ]; then
        return 0
    fi
    command -v sync >/dev/null 2>&1 || return 4
    case "$(uname -s 2>/dev/null)" in
        Darwin) command sync >/dev/null 2>&1 ;;
        *) command sync -f "$path" >/dev/null 2>&1 ;;
    esac
}
dotfiles_config_owned_path_matches() {
    local path=$1
    local identity=$2

    [ -n "$path" ] || return 1
    [ ! -L "$path" ] || return 1
    [ "$(dotfiles_config_stat_identity "$path")" = "$identity" ] 2>/dev/null
}

dotfiles_config_open_lock_handle() {
    local fd

    for fd in 9 8 7 6 5 4 3; do
        if (: <&"$fd") 2>/dev/null; then
            continue
        fi
        if eval "exec ${fd}<\"\${DOTFILES_CONFIG_LOCK_PATH}\"" 2>/dev/null; then
            DOTFILES_CONFIG_LOCK_FD=$fd
            DOTFILES_CONFIG_LOCK_FD_OPEN=1
            return 0
        fi
    done
    return 1
}

dotfiles_config_close_lock_handle() {
    if [ "${DOTFILES_CONFIG_LOCK_FD_OPEN:-0}" -eq 1 ]; then
        eval "exec ${DOTFILES_CONFIG_LOCK_FD}<&-" 2>/dev/null || true
        DOTFILES_CONFIG_LOCK_FD_OPEN=0
        DOTFILES_CONFIG_LOCK_FD=
    fi
}

dotfiles_config_lock_handle_identity() {
    local inode

    [ "${DOTFILES_CONFIG_LOCK_FD_OPEN:-0}" -eq 1 ] || return 1
    [ -n "${DOTFILES_CONFIG_LOCK_FD:-}" ] || return 1
    [ -n "${DOTFILES_CONFIG_LOCK_DEVICE:-}" ] || return 1
    # macOS exposes the target inode through /dev/fd but reports the devfs
    # device. A newly created directory inherits the validated parent device,
    # captured before mkdir, so that device plus the followed inode is exact.
    inode=$(dotfiles_config_stat_followed_inode "/dev/fd/${DOTFILES_CONFIG_LOCK_FD}") || return 1
    printf '%s:%s\n' "$DOTFILES_CONFIG_LOCK_DEVICE" "$inode"
}

dotfiles_config_lock_handle_matches_path() {
    local handle_identity
    local path_identity

    [ "${DOTFILES_CONFIG_LOCK_FD_OPEN:-0}" -eq 1 ] || return 1
    [ -n "${DOTFILES_CONFIG_LOCK_FD:-}" ] || return 1
    [ ! -L "$DOTFILES_CONFIG_LOCK_PATH" ] || return 1
    [ -d "$DOTFILES_CONFIG_LOCK_PATH" ] || return 1
    path_identity=$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_LOCK_PATH") || return 1
    handle_identity=$(dotfiles_config_lock_handle_identity) || return 1
    [ "$path_identity" = "$handle_identity" ]
}

dotfiles_config_owned_lock_matches() {
    [ "${DOTFILES_CONFIG_LOCK_OWNED:-0}" -eq 1 ] || return 1
    if [ "${DOTFILES_CONFIG_LOCK_FD_OPEN:-0}" -eq 1 ]; then
        dotfiles_config_lock_handle_matches_path || return 1
    fi
    if [ -n "${DOTFILES_CONFIG_LOCK_IDENTITY:-}" ]; then
        dotfiles_config_owned_path_matches "$DOTFILES_CONFIG_LOCK_PATH" "$DOTFILES_CONFIG_LOCK_IDENTITY" || return 1
    else
        [ "${DOTFILES_CONFIG_LOCK_FD_OPEN:-0}" -eq 1 ] || return 1
    fi
}

dotfiles_config_validate_owned_lock() {
    dotfiles_config_owned_lock_matches || return 1
    dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_LOCK_PATH" || return 1
    [ "$(dotfiles_config_stat_mode "$DOTFILES_CONFIG_LOCK_PATH")" = 700 ] || return 1
}

dotfiles_config_cleanup() {
    if ! dotfiles_config_revalidate_directories >/dev/null 2>&1; then
        return 0
    fi
    if [ "${DOTFILES_CONFIG_TEMP_OWNED:-0}" -eq 1 ] && dotfiles_config_owned_path_matches "$DOTFILES_CONFIG_TEMP_PATH" "$DOTFILES_CONFIG_TEMP_IDENTITY"; then
        rm -f "$DOTFILES_CONFIG_TEMP_PATH" 2>/dev/null || true
    fi
    if [ "${DOTFILES_CONFIG_SNAPSHOT_OWNED:-0}" -eq 1 ] && dotfiles_config_owned_path_matches "$DOTFILES_CONFIG_SNAPSHOT_PATH" "$DOTFILES_CONFIG_SNAPSHOT_IDENTITY"; then
        rm -f "$DOTFILES_CONFIG_SNAPSHOT_PATH" 2>/dev/null || true
    fi
    if dotfiles_config_owned_lock_matches; then
        rmdir "$DOTFILES_CONFIG_LOCK_PATH" 2>/dev/null || true
    fi
    dotfiles_config_close_lock_handle
}

dotfiles_config_handle_signal() {
    local status=$1

    if [ "${DOTFILES_CONFIG_COMMIT_CRITICAL:-0}" -eq 1 ]; then
        DOTFILES_CONFIG_PENDING_SIGNAL=$status
        return 0
    fi
    exit "$status"
}

dotfiles_config_release_lock() {
    dotfiles_config_owned_lock_matches || return 1
    rmdir "$DOTFILES_CONFIG_LOCK_PATH" 2>/dev/null || return 1
    DOTFILES_CONFIG_LOCK_OWNED=0
    dotfiles_config_close_lock_handle
}

dotfiles_config_acquire_lock() {
    if [ -e "$DOTFILES_CONFIG_LOCK_PATH" ] || [ -L "$DOTFILES_CONFIG_LOCK_PATH" ]; then
        dotfiles_config_lock_error
        return 3
    fi

    DOTFILES_CONFIG_LOCK_DEVICE=$(dotfiles_config_stat_device "$DOTFILES_CONFIG_DIRECTORY") || {
        dotfiles_config_uncertain_error
        return 4
    }
    umask 077
    mkdir "$DOTFILES_CONFIG_LOCK_PATH" 2>/dev/null || {
        dotfiles_config_lock_error
        return 3
    }

    # Keep an open handle to the exact directory created by mkdir. It provides
    # cleanup authority even when later identity capture or validation fails,
    # and prevents an externally replaced path from matching the owned object.
    dotfiles_config_open_lock_handle || {
        DOTFILES_CONFIG_LOCK_IDENTITY=$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_LOCK_PATH") || {
            dotfiles_config_uncertain_error
            return 4
        }
    }
    DOTFILES_CONFIG_LOCK_OWNED=1

    dotfiles_config_hook AFTER_LOCK_CREATE || {
        dotfiles_config_uncertain_error
        return 4
    }
    dotfiles_config_hook LOCK_IDENTITY_CAPTURE || {
        dotfiles_config_uncertain_error
        return 4
    }
    if [ -z "$DOTFILES_CONFIG_LOCK_IDENTITY" ]; then
        DOTFILES_CONFIG_LOCK_IDENTITY=$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_LOCK_PATH") || {
            dotfiles_config_uncertain_error
            return 4
        }
    fi
    dotfiles_config_hook LOCK_IDENTITY_VALIDATION || {
        dotfiles_config_uncertain_error
        return 4
    }
    dotfiles_config_validate_owned_lock || {
        dotfiles_config_uncertain_error
        return 4
    }
    dotfiles_config_hook AFTER_LOCK || {
        dotfiles_config_uncertain_error
        return 4
    }
}
