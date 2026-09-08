# Source-only snapshots, comparison, atomic publication, and writer entrypoints.

dotfiles_config_make_private_file() {
    local kind=$1
    local template=$2
    local path
    local identity

    path=$(mktemp "$template" 2>/dev/null) || return 1
    chmod 600 "$path" 2>/dev/null || {
        rm -f "$path" 2>/dev/null || true
        return 1
    }
    if [ -L "$path" ] || [ ! -f "$path" ] || \
        [ "$(dotfiles_config_stat_owner "$path")" != "$(id -u)" ] || \
        [ "$(dotfiles_config_stat_mode "$path")" != 600 ]; then
        rm -f "$path" 2>/dev/null || true
        return 1
    fi
    identity=$(dotfiles_config_stat_identity "$path") || {
        rm -f "$path" 2>/dev/null || true
        return 1
    }

    if [ "$kind" = temp ]; then
        DOTFILES_CONFIG_TEMP_PATH=$path
        DOTFILES_CONFIG_TEMP_IDENTITY=$identity
        DOTFILES_CONFIG_TEMP_OWNED=1
    else
        DOTFILES_CONFIG_SNAPSHOT_PATH=$path
        DOTFILES_CONFIG_SNAPSHOT_IDENTITY=$identity
        DOTFILES_CONFIG_SNAPSHOT_OWNED=1
    fi
}

dotfiles_config_snapshot_matches_current() {
    if [ "$DOTFILES_CONFIG_PRIOR_PRESENT" -eq 0 ]; then
        [ ! -e "$DOTFILES_CONFIG_STATE_PATH" ] && [ ! -L "$DOTFILES_CONFIG_STATE_PATH" ]
        return
    fi
    dotfiles_config_owned_path_matches "$DOTFILES_CONFIG_SNAPSHOT_PATH" "$DOTFILES_CONFIG_SNAPSHOT_IDENTITY" || return 1
    [ -f "$DOTFILES_CONFIG_SNAPSHOT_PATH" ] || return 1
    [ "$(dotfiles_config_stat_owner "$DOTFILES_CONFIG_SNAPSHOT_PATH")" = "$(id -u)" ] || return 1
    [ "$(dotfiles_config_stat_mode "$DOTFILES_CONFIG_SNAPSHOT_PATH")" = 600 ] || return 1
    dotfiles_config_validate_state_path || return 1
    cmp -s "$DOTFILES_CONFIG_STATE_PATH" "$DOTFILES_CONFIG_SNAPSHOT_PATH"
}

dotfiles_config_file_matches_body() {
    local file=$1
    local body=$2
    local actual_body
    local byte_count
    local expected_size

    [ ! -L "$file" ] || return 1
    [ -f "$file" ] && [ -r "$file" ] || return 1
    [ "$(dotfiles_config_stat_owner "$file")" = "$(id -u)" ] || return 1
    [ "$(dotfiles_config_stat_mode "$file")" = 600 ] || return 1
    actual_body=$(< "$file") || return 1
    [ "$actual_body" = "$body" ] || return 1
    byte_count=$(LC_ALL=C wc -c < "$file") || return 1
    byte_count=${byte_count//[[:space:]]/}
    expected_size=$((${#body} + 1))
    [ "$byte_count" -eq "$expected_size" ] 2>/dev/null
}

dotfiles_config_state_matches_body() {
    dotfiles_config_validate_state_path || return 1
    dotfiles_config_file_matches_body "$DOTFILES_CONFIG_STATE_PATH" "$1"
}

dotfiles_config_capture_current_state() {
    local platform=$1
    local current_status

    DOTFILES_CONFIG_PRIOR_PRESENT=0
    if [ ! -e "$DOTFILES_CONFIG_STATE_PATH" ]; then
        return 0
    fi

    DOTFILES_CONFIG_PRIOR_PRESENT=1
    dotfiles_config_make_private_file snapshot "${DOTFILES_CONFIG_DIRECTORY}/.active-selection.prior.XXXXXX" || {
        dotfiles_config_uncertain_error
        return 4
    }
    cp "$DOTFILES_CONFIG_STATE_PATH" "$DOTFILES_CONFIG_SNAPSHOT_PATH" 2>/dev/null || {
        dotfiles_config_uncertain_error
        return 4
    }
    chmod 600 "$DOTFILES_CONFIG_SNAPSHOT_PATH" 2>/dev/null || {
        dotfiles_config_uncertain_error
        return 4
    }
    DOTFILES_CONFIG_SNAPSHOT_IDENTITY=$(dotfiles_config_stat_identity "$DOTFILES_CONFIG_SNAPSHOT_PATH") || {
        dotfiles_config_uncertain_error
        return 4
    }
    dotfiles_config_revalidate_tree && \
        cmp -s "$DOTFILES_CONFIG_STATE_PATH" "$DOTFILES_CONFIG_SNAPSHOT_PATH" || {
        dotfiles_config_state_error
        return 3
    }
    dotfiles_config_validate_saved_selection "$DOTFILES_CONFIG_SNAPSHOT_PATH" "$platform"
    current_status=$?
    if [ "$current_status" -ne 0 ]; then
        dotfiles_config_state_error
        [ "$current_status" -eq 4 ] && return 4
        return 3
    fi
    dotfiles_config_snapshot_matches_current || {
        dotfiles_config_state_error
        return 3
    }
}

dotfiles_config_print_result() {
    local result=$1
    local output_mode=$2

    if [ "$output_mode" = public ]; then
        if [ "$result" = saved ]; then
            printf 'Local selection saved.\n'
        else
            printf 'Local selection unchanged.\n'
        fi
        printf 'Managed home configuration: unchanged.\n'
    else
        printf '%s\n' "$result"
    fi
}

dotfiles_config_initialize_operation() {
    local private_root=$1

    DOTFILES_CONFIG_OPERATION_MODE=write
    DOTFILES_CONFIG_PRIVATE_ROOT_ACTIVE=$private_root
    DOTFILES_CONFIG_ROOT=
    DOTFILES_CONFIG_ROOT_LABEL=
    DOTFILES_CONFIG_DIRECTORY=
    DOTFILES_CONFIG_STATE_PATH=
    DOTFILES_CONFIG_LOCK_PATH=
    DOTFILES_CONFIG_TEMP_PATH=
    DOTFILES_CONFIG_TEMP_IDENTITY=
    DOTFILES_CONFIG_TEMP_OWNED=0
    DOTFILES_CONFIG_SNAPSHOT_PATH=
    DOTFILES_CONFIG_SNAPSHOT_IDENTITY=
    DOTFILES_CONFIG_SNAPSHOT_OWNED=0
    DOTFILES_CONFIG_LOCK_OWNED=0
    DOTFILES_CONFIG_LOCK_IDENTITY=
    DOTFILES_CONFIG_LOCK_DEVICE=
    DOTFILES_CONFIG_LOCK_FD=
    DOTFILES_CONFIG_LOCK_FD_OPEN=0
    DOTFILES_CONFIG_PRIOR_PRESENT=0
    DOTFILES_CONFIG_COMMIT_CRITICAL=0
    DOTFILES_CONFIG_PENDING_SIGNAL=0

    trap dotfiles_config_cleanup EXIT
    trap 'dotfiles_config_handle_signal 129' HUP
    trap 'dotfiles_config_handle_signal 130' INT
    trap 'dotfiles_config_handle_signal 143' TERM
}

dotfiles_config_state_compare_core() {
    local private_root=$1
    local profile=$2
    local modules=$3
    local additional=$4
    local platform=$5
    local proposed_body
    local comparison=different

    dotfiles_config_initialize_operation "$private_root"
    dotfiles_config_validate_intent "$profile" "$modules" "$additional" || return $?
    dotfiles_config_build_body "$profile" "$modules" "$additional"
    proposed_body=$DOTFILES_CONFIG_BODY
    dotfiles_config_require_tools || return $?
    dotfiles_config_derive_root "$private_root" || return $?
    dotfiles_config_set_paths

    if [ ! -e "$DOTFILES_CONFIG_ROOT" ] && [ ! -L "$DOTFILES_CONFIG_ROOT" ]; then
        printf 'different\n'
        return 0
    fi
    dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_ROOT" || {
        dotfiles_config_storage_error
        return 3
    }
    [ -w "$DOTFILES_CONFIG_ROOT" ] && [ -x "$DOTFILES_CONFIG_ROOT" ] || {
        dotfiles_config_storage_error
        return 3
    }

    if [ ! -e "$DOTFILES_CONFIG_DIRECTORY" ] && [ ! -L "$DOTFILES_CONFIG_DIRECTORY" ]; then
        printf 'different\n'
        return 0
    fi
    dotfiles_config_revalidate_directories || {
        dotfiles_config_storage_error
        return 3
    }
    dotfiles_config_validate_state_path || {
        dotfiles_config_state_error
        return 3
    }

    if [ ! -e "$DOTFILES_CONFIG_STATE_PATH" ]; then
        if [ -e "$DOTFILES_CONFIG_LOCK_PATH" ] || [ -L "$DOTFILES_CONFIG_LOCK_PATH" ]; then
            dotfiles_config_lock_error
            return 3
        fi
        printf 'different\n'
        return 0
    fi

    dotfiles_config_acquire_lock || return $?
    dotfiles_config_revalidate_tree || {
        dotfiles_config_state_error
        return 3
    }
    dotfiles_config_capture_current_state "$platform" || return $?
    if [ "$DOTFILES_CONFIG_PRIOR_PRESENT" -eq 1 ] && \
        dotfiles_config_state_matches_body "$proposed_body"; then
        comparison=same
    fi
    dotfiles_config_revalidate_tree && dotfiles_config_snapshot_matches_current || {
        dotfiles_config_state_error
        return 3
    }
    dotfiles_config_release_lock || {
        dotfiles_config_uncertain_error
        return 4
    }
    printf '%s\n' "$comparison"
}

dotfiles_config_state_set_core() {
    local output_mode=$1
    local private_root=$2
    local profile=$3
    local modules=$4
    local additional=$5
    local platform=$6
    local proposed_body
    local post_commit_failure=0
    local rename_status=0

    dotfiles_config_initialize_operation "$private_root"
    dotfiles_config_validate_intent "$profile" "$modules" "$additional" || return $?
    dotfiles_config_build_body "$profile" "$modules" "$additional"
    proposed_body=$DOTFILES_CONFIG_BODY
    dotfiles_config_require_tools || return $?

    dotfiles_config_derive_root "$private_root" || return $?
    dotfiles_config_prepare_root || return $?
    dotfiles_config_prepare_directory || return $?
    dotfiles_config_revalidate_directories || {
        dotfiles_config_storage_error
        return 3
    }
    dotfiles_config_validate_state_path || {
        dotfiles_config_state_error
        return 3
    }

    dotfiles_config_acquire_lock || return $?

    dotfiles_config_revalidate_tree || {
        dotfiles_config_state_error
        return 3
    }

    dotfiles_config_capture_current_state "$platform" || return $?
    if [ "$DOTFILES_CONFIG_PRIOR_PRESENT" -eq 1 ]; then
        if dotfiles_config_state_matches_body "$proposed_body"; then
            dotfiles_config_revalidate_tree && dotfiles_config_snapshot_matches_current || {
                dotfiles_config_state_error
                return 3
            }
            dotfiles_config_release_lock || {
                dotfiles_config_uncertain_error
                return 4
            }
            dotfiles_config_print_result unchanged "$output_mode"
            return 0
        fi
    fi

    dotfiles_config_make_private_file temp "${DOTFILES_CONFIG_DIRECTORY}/.active-selection.tmp.XXXXXX" || {
        dotfiles_config_uncertain_error
        return 4
    }
    printf '%s\n' "$proposed_body" > "$DOTFILES_CONFIG_TEMP_PATH" || {
        dotfiles_config_uncertain_error
        return 4
    }
    chmod 600 "$DOTFILES_CONFIG_TEMP_PATH" 2>/dev/null || {
        dotfiles_config_uncertain_error
        return 4
    }
    dotfiles_config_file_matches_body "$DOTFILES_CONFIG_TEMP_PATH" "$proposed_body" || {
        dotfiles_config_uncertain_error
        return 4
    }
    dotfiles_config_hook AFTER_TEMP_WRITE || {
        dotfiles_config_uncertain_error
        return 4
    }
    dotfiles_config_owned_path_matches "$DOTFILES_CONFIG_TEMP_PATH" "$DOTFILES_CONFIG_TEMP_IDENTITY" && \
        dotfiles_config_file_matches_body "$DOTFILES_CONFIG_TEMP_PATH" "$proposed_body" || {
        dotfiles_config_state_error
        return 3
    }
    dotfiles_config_flush FILE "$DOTFILES_CONFIG_TEMP_PATH" || {
        dotfiles_config_uncertain_error
        return 4
    }

    DOTFILES_CONFIG_COMMIT_CRITICAL=1
    if ! dotfiles_config_revalidate_tree || \
        ! dotfiles_config_snapshot_matches_current || \
        ! dotfiles_config_owned_path_matches "$DOTFILES_CONFIG_TEMP_PATH" "$DOTFILES_CONFIG_TEMP_IDENTITY" || \
        ! dotfiles_config_file_matches_body "$DOTFILES_CONFIG_TEMP_PATH" "$proposed_body"; then
        DOTFILES_CONFIG_COMMIT_CRITICAL=0
        if [ "$DOTFILES_CONFIG_PENDING_SIGNAL" -ne 0 ]; then
            return "$DOTFILES_CONFIG_PENDING_SIGNAL"
        fi
        dotfiles_config_state_error
        return 3
    fi
    if ! dotfiles_config_hook AFTER_FINAL_CHECK; then
        DOTFILES_CONFIG_COMMIT_CRITICAL=0
        if [ "$DOTFILES_CONFIG_PENDING_SIGNAL" -ne 0 ]; then
            return "$DOTFILES_CONFIG_PENDING_SIGNAL"
        fi
        dotfiles_config_uncertain_error
        return 4
    fi
    if ! dotfiles_config_hook BEFORE_RENAME; then
        DOTFILES_CONFIG_COMMIT_CRITICAL=0
        if [ "$DOTFILES_CONFIG_PENDING_SIGNAL" -ne 0 ]; then
            return "$DOTFILES_CONFIG_PENDING_SIGNAL"
        fi
        dotfiles_config_uncertain_error
        return 4
    fi
    mv -f "$DOTFILES_CONFIG_TEMP_PATH" "$DOTFILES_CONFIG_STATE_PATH" 2>/dev/null || rename_status=$?
    if [ "$rename_status" -eq 0 ]; then
        DOTFILES_CONFIG_TEMP_OWNED=0
    elif dotfiles_config_state_matches_body "$proposed_body" && \
        [ ! -e "$DOTFILES_CONFIG_TEMP_PATH" ] && [ ! -L "$DOTFILES_CONFIG_TEMP_PATH" ]; then
        DOTFILES_CONFIG_TEMP_OWNED=0
        post_commit_failure=1
    else
        DOTFILES_CONFIG_COMMIT_CRITICAL=0
        if [ "$DOTFILES_CONFIG_PENDING_SIGNAL" -ne 0 ]; then
            return "$DOTFILES_CONFIG_PENDING_SIGNAL"
        fi
        dotfiles_config_uncertain_error
        return 4
    fi

    dotfiles_config_hook AFTER_RENAME || post_commit_failure=1
    dotfiles_config_revalidate_tree || post_commit_failure=1
    dotfiles_config_state_matches_body "$proposed_body" || post_commit_failure=1
    dotfiles_config_flush DIRECTORY "$DOTFILES_CONFIG_DIRECTORY" || post_commit_failure=1
    dotfiles_config_hook AFTER_DIRECTORY_FLUSH || post_commit_failure=1
    dotfiles_config_revalidate_tree || post_commit_failure=1
    dotfiles_config_state_matches_body "$proposed_body" || post_commit_failure=1
    DOTFILES_CONFIG_COMMIT_CRITICAL=0

    if [ "$DOTFILES_CONFIG_PENDING_SIGNAL" -ne 0 ]; then
        return "$DOTFILES_CONFIG_PENDING_SIGNAL"
    fi
    if [ "$post_commit_failure" -ne 0 ]; then
        dotfiles_config_uncertain_error
        return 4
    fi
    dotfiles_config_release_lock || {
        dotfiles_config_uncertain_error
        return 4
    }
    dotfiles_config_print_result saved "$output_mode"
}

dotfiles_config_state_set_internal() (
    dotfiles_config_state_set_core internal "$@"
)

dotfiles_config_state_compare_internal() (
    dotfiles_config_state_compare_core "$@"
)

dotfiles_config_state_compare() (
    dotfiles_config_state_compare_core "" "$@"
)

dotfiles_config_state_set() {
    dotfiles_config_state_set_core public "" "$@"
}
