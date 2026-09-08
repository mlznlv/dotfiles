# Source-only descriptor-preserving verified reads and strict saved-state loading.

dotfiles_config_open_read_handle() {
    local fd

    dotfiles_config_hook READ_HANDLE_OPEN || return 1
    # Bash 3.2 has no dynamic {var} descriptor allocation. Scan its portable
    # numeric range instead, preserving every descriptor inherited by callers.
    # Descriptor 255 is reserved internally by Bash 3.2 while reading scripts.
    for ((fd = 254; fd >= 3; fd--)); do
        # Probe both directions without performing I/O. Bash 3.2 rejects an
        # input duplication for a write-only descriptor and an output
        # duplication for a read-only descriptor; either success means the
        # caller already owns the descriptor and it must not be replaced.
        if (: <&"$fd") 2>/dev/null || (: >&"$fd") 2>/dev/null; then
            continue
        fi
        if eval "exec ${fd}<\"\${DOTFILES_CONFIG_STATE_PATH}\"" 2>/dev/null; then
            DOTFILES_CONFIG_READ_FD=$fd
            DOTFILES_CONFIG_READ_FD_OPEN=1
            return 0
        fi
    done
    return 1
}
dotfiles_config_close_read_handle() {
    if [ "${DOTFILES_CONFIG_READ_FD_OPEN:-0}" -eq 1 ]; then
        eval "exec ${DOTFILES_CONFIG_READ_FD}<&-" 2>/dev/null || true
        DOTFILES_CONFIG_READ_FD_OPEN=0
        DOTFILES_CONFIG_READ_FD=
    fi
}

dotfiles_config_read_handle_identity() {
    local inode

    [ "${DOTFILES_CONFIG_READ_FD_OPEN:-0}" -eq 1 ] || return 1
    [ -n "${DOTFILES_CONFIG_READ_DEVICE:-}" ] || return 1
    inode=$(dotfiles_config_stat_followed_inode "/dev/fd/${DOTFILES_CONFIG_READ_FD}") || return 1
    printf '%s:%s\n' "$DOTFILES_CONFIG_READ_DEVICE" "$inode"
}

dotfiles_config_read_verified_once() {
    local expected_identity=$1
    local handle_identity
    local size_before
    local size_after
    local body
    local expected_size
    local LC_ALL=C

    if ! dotfiles_config_open_read_handle; then
        if dotfiles_config_validate_read_directories &&
           dotfiles_config_validate_state_path &&
           [ "$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_STATE_PATH")" = "$expected_identity" ]; then
            return 4
        fi
        return 3
    fi
    handle_identity=$(dotfiles_config_read_handle_identity) || {
        dotfiles_config_close_read_handle
        return 3
    }
    if [ "$handle_identity" != "$expected_identity" ] ||
       ! dotfiles_config_validate_read_directories ||
       ! dotfiles_config_validate_state_path ||
       [ "$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_STATE_PATH")" != "$expected_identity" ]; then
        dotfiles_config_close_read_handle
        return 3
    fi

    size_before=$(dotfiles_config_stat_followed_size "/dev/fd/${DOTFILES_CONFIG_READ_FD}") || {
        dotfiles_config_close_read_handle
        return 3
    }
    body=$(cat <&$DOTFILES_CONFIG_READ_FD) || {
        dotfiles_config_close_read_handle
        return 3
    }
    size_after=$(dotfiles_config_stat_followed_size "/dev/fd/${DOTFILES_CONFIG_READ_FD}") || {
        dotfiles_config_close_read_handle
        return 3
    }
    handle_identity=$(dotfiles_config_read_handle_identity) || {
        dotfiles_config_close_read_handle
        return 3
    }
    dotfiles_config_close_read_handle

    expected_size=$((${#body} + 1))
    [ "$handle_identity" = "$expected_identity" ] || return 1
    [ "$size_before" = "$size_after" ] || return 1
    [ "$size_before" -eq "$expected_size" ] 2>/dev/null || return 1
    dotfiles_config_validate_read_directories || return 1
    dotfiles_config_validate_state_path || return 1
    [ "$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_STATE_PATH")" = "$expected_identity" ] || return 1

    DOTFILES_CONFIG_READ_BODY=$body
    DOTFILES_CONFIG_READ_SIZE=$size_before
}

dotfiles_config_read_verified_or_report() {
    local status

    dotfiles_config_read_verified_once "$1"
    status=$?
    case "$status" in
        0) return 0 ;;
        1|3)
            dotfiles_config_read_drift_error
            return 3
            ;;
        4)
            dotfiles_config_read_handle_error
            return 4
            ;;
        *)
            printf 'error: local selection read validation failed\n' >&2
            return 4
            ;;
    esac
}

dotfiles_config_validate_saved_selection() {
    local file=$1
    local platform=$2
    local result

    dotfiles_config_parse_file "$file" || return 3
    result=$(run_catalog resolve "$platform" 0 "" \
        "$DOTFILES_CONFIG_PARSED_PROFILE" \
        "$DOTFILES_CONFIG_PARSED_MODULES" \
        "$DOTFILES_CONFIG_PARSED_ADDITIONAL" 2>/dev/null) || return $?
    [ -n "$result" ] || return 3
}

dotfiles_config_state_load_core() {
    local private_root=$1
    local platform=$2
    local identity
    local first_body
    local first_size
    local second_body
    local second_size
    local validation_status
    local result

    DOTFILES_CONFIG_OPERATION_MODE=read
    DOTFILES_CONFIG_PRIVATE_ROOT_ACTIVE=$private_root
    DOTFILES_CONFIG_ROOT=
    DOTFILES_CONFIG_ROOT_LABEL=
    DOTFILES_CONFIG_DIRECTORY=
    DOTFILES_CONFIG_STATE_PATH=
    DOTFILES_CONFIG_READ_FD=
    DOTFILES_CONFIG_READ_FD_OPEN=0
    DOTFILES_CONFIG_READ_DEVICE=
    DOTFILES_CONFIG_READ_BODY=
    DOTFILES_CONFIG_READ_SIZE=
    DOTFILES_CONFIG_LOADED_PROFILE=
    DOTFILES_CONFIG_LOADED_MODULES=
    DOTFILES_CONFIG_LOADED_ADDITIONAL=
    DOTFILES_CONFIG_LOADED_SNAPSHOT=

    dotfiles_config_require_read_tools || return $?
    dotfiles_config_derive_root "$private_root" || return $?
    dotfiles_config_set_paths

    if [ ! -e "$DOTFILES_CONFIG_ROOT" ] && [ ! -L "$DOTFILES_CONFIG_ROOT" ]; then
        dotfiles_config_missing_state_error
        return 3
    fi
    if [ ! -e "$DOTFILES_CONFIG_DIRECTORY" ] && [ ! -L "$DOTFILES_CONFIG_DIRECTORY" ]; then
        dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_ROOT" &&
            dotfiles_config_path_is_outside_project "$DOTFILES_CONFIG_ROOT" &&
            [ -r "$DOTFILES_CONFIG_ROOT" ] && [ -x "$DOTFILES_CONFIG_ROOT" ] || {
            dotfiles_config_storage_error
            return 3
        }
        dotfiles_config_missing_state_error
        return 3
    fi
    dotfiles_config_validate_read_directories || {
        dotfiles_config_storage_error
        return 3
    }
    if [ ! -e "$DOTFILES_CONFIG_STATE_PATH" ] && [ ! -L "$DOTFILES_CONFIG_STATE_PATH" ]; then
        dotfiles_config_missing_state_error
        return 3
    fi
    dotfiles_config_validate_state_path || {
        dotfiles_config_state_error
        return 3
    }

    identity=$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_STATE_PATH") || {
        dotfiles_config_read_drift_error
        return 3
    }
    DOTFILES_CONFIG_READ_DEVICE=$(dotfiles_config_stat_device "$DOTFILES_CONFIG_STATE_PATH") || {
        dotfiles_config_read_drift_error
        return 3
    }
    dotfiles_config_hook BEFORE_READ_OPEN || return 4
    dotfiles_config_read_verified_or_report "$identity" || return $?
    first_body=$DOTFILES_CONFIG_READ_BODY
    first_size=$DOTFILES_CONFIG_READ_SIZE

    dotfiles_config_hook AFTER_FIRST_READ || return 4
    dotfiles_config_read_verified_or_report "$identity" || return $?
    second_body=$DOTFILES_CONFIG_READ_BODY
    second_size=$DOTFILES_CONFIG_READ_SIZE
    [ "$first_size" = "$second_size" ] && [ "$first_body" = "$second_body" ] || {
        dotfiles_config_read_drift_error
        return 3
    }
    dotfiles_config_hook AFTER_SECOND_READ || return 4
    dotfiles_config_validate_read_directories &&
        dotfiles_config_validate_state_path &&
        [ "$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_STATE_PATH")" = "$identity" ] || {
        dotfiles_config_read_drift_error
        return 3
    }

    dotfiles_config_parse_body "$second_body" "$second_size" || {
        dotfiles_config_state_error
        return 3
    }
    result=$(run_catalog resolve "$platform" 0 "" \
        "$DOTFILES_CONFIG_PARSED_PROFILE" \
        "$DOTFILES_CONFIG_PARSED_MODULES" \
        "$DOTFILES_CONFIG_PARSED_ADDITIONAL" 2>/dev/null)
    validation_status=$?
    if [ "$validation_status" -ne 0 ] || [ -z "$result" ]; then
        dotfiles_config_state_error
        [ "$validation_status" -eq 4 ] && return 4
        return 3
    fi

    dotfiles_config_hook AFTER_READ_VALIDATION || return 4
    dotfiles_config_validate_read_directories &&
        dotfiles_config_validate_state_path &&
        [ "$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_STATE_PATH")" = "$identity" ] || {
        dotfiles_config_read_drift_error
        return 3
    }
    dotfiles_config_read_verified_or_report "$identity" || return $?
    [ "$DOTFILES_CONFIG_READ_SIZE" = "$second_size" ] &&
        [ "$DOTFILES_CONFIG_READ_BODY" = "$second_body" ] || {
        dotfiles_config_read_drift_error
        return 3
    }

    DOTFILES_CONFIG_LOADED_PROFILE=$DOTFILES_CONFIG_PARSED_PROFILE
    DOTFILES_CONFIG_LOADED_MODULES=$DOTFILES_CONFIG_PARSED_MODULES
    DOTFILES_CONFIG_LOADED_ADDITIONAL=$DOTFILES_CONFIG_PARSED_ADDITIONAL
    DOTFILES_CONFIG_LOADED_SNAPSHOT="identity=${identity}
bytes=${second_size}
${second_body}"
}

dotfiles_config_state_load_internal() {
    [ "$#" -eq 2 ] || return 4
    dotfiles_config_state_load_core "$1" "$2"
}

dotfiles_config_state_load() {
    [ "$#" -eq 1 ] || return 4
    dotfiles_config_state_load_core "" "$1"
}
