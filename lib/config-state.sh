#!/usr/bin/env bash

# Private local-selection comparison and persistence for configuration commands.
# This file is sourced by bin/dotfiles and intentionally exposes no CLI path
# override. Tests use private internal wrappers with an isolated root.

dotfiles_config_identifier_is_valid() {
    [[ $1 =~ ^[a-z][a-z0-9]*([.][a-z][a-z0-9-]*)+$ ]]
}

dotfiles_config_list_is_valid() {
    local value=$1
    local allow_empty=${2:-1}
    local item
    local left
    local right
    local rebuilt=
    local i
    local j
    local -a items=()

    if [ -z "$value" ]; then
        [ "$allow_empty" -eq 1 ]
        return
    fi
    case "$value" in
        ,*|*,|*,,*) return 1 ;;
    esac

    IFS=, read -r -a items <<< "$value"
    [ "${#items[@]}" -gt 0 ] || return 1
    for item in "${items[@]}"; do
        dotfiles_config_identifier_is_valid "$item" || return 1
        if [ -n "$rebuilt" ]; then
            rebuilt="${rebuilt},${item}"
        else
            rebuilt=$item
        fi
    done
    [ "$rebuilt" = "$value" ] || return 1

    for ((i = 0; i < ${#items[@]}; i++)); do
        left=${items[$i]}
        for ((j = i + 1; j < ${#items[@]}; j++)); do
            right=${items[$j]}
            [ "$left" != "$right" ] || return 1
        done
    done
}

dotfiles_config_validate_intent() {
    local profile=$1
    local modules=$2
    local additional=$3
    local module
    local extra
    local modules_allow_empty=0
    local -a module_items=()
    local -a additional_items=()

    if [ -n "$profile" ] && [ -n "$modules" ]; then
        printf 'error: profile and module selection cannot be combined\n' >&2
        return 3
    fi
    if [ -z "$profile" ] && [ -z "$modules" ]; then
        printf 'error: local selection requires a profile or modules\n' >&2
        return 3
    fi
    if [ -n "$profile" ] && ! dotfiles_config_identifier_is_valid "$profile"; then
        printf 'error: invalid profile identifier\n' >&2
        return 3
    fi
    [ -z "$profile" ] || modules_allow_empty=1
    if ! dotfiles_config_list_is_valid "$modules" "$modules_allow_empty"; then
        printf 'error: invalid explicit module selection\n' >&2
        return 3
    fi
    if ! dotfiles_config_list_is_valid "$additional" 1; then
        printf 'error: invalid additional module selection\n' >&2
        return 3
    fi

    if [ -n "$modules" ] && [ -n "$additional" ]; then
        IFS=, read -r -a module_items <<< "$modules"
        IFS=, read -r -a additional_items <<< "$additional"
        for module in "${module_items[@]}"; do
            for extra in "${additional_items[@]}"; do
                if [ "$module" = "$extra" ]; then
                    printf 'error: a module cannot appear in both base and additional selections\n' >&2
                    return 3
                fi
            done
        done
    fi
}

dotfiles_config_format_array() {
    local value=$1
    local item
    local output='['
    local separator=
    local -a items=()

    if [ -n "$value" ]; then
        IFS=, read -r -a items <<< "$value"
        for item in "${items[@]}"; do
            output="${output}${separator}\"${item}\""
            separator=', '
        done
    fi
    DOTFILES_CONFIG_ARRAY="${output}]"
}

dotfiles_config_build_body() {
    local profile=$1
    local modules=$2
    local additional=$3
    local base_line
    local additional_array

    if [ -n "$profile" ]; then
        base_line="profile = \"${profile}\""
    else
        dotfiles_config_format_array "$modules"
        base_line="modules = ${DOTFILES_CONFIG_ARRAY}"
    fi
    dotfiles_config_format_array "$additional"
    additional_array=$DOTFILES_CONFIG_ARRAY
    DOTFILES_CONFIG_BODY="schema = 1

[selection]
${base_line}
additional_modules = ${additional_array}"
}

dotfiles_config_parse_array() {
    local encoded=$1
    local inner
    local csv

    if [ "$encoded" = '[]' ]; then
        DOTFILES_CONFIG_PARSED_ARRAY=
        return 0
    fi
    case "$encoded" in
        '["'*'"]') ;;
        *) return 1 ;;
    esac
    inner=${encoded#'["'}
    inner=${inner%'"]'}
    csv=${inner//\", \"/,}
    dotfiles_config_list_is_valid "$csv" 0 || return 1
    dotfiles_config_format_array "$csv"
    [ "$DOTFILES_CONFIG_ARRAY" = "$encoded" ] || return 1
    DOTFILES_CONFIG_PARSED_ARRAY=$csv
}

dotfiles_config_parse_file() {
    local file=$1
    local line
    local base_value
    local additional_value
    local actual_body
    local byte_count
    local expected_size
    local profile=
    local modules=
    local additional=
    local -a lines=()

    while IFS= read -r line || [ -n "$line" ]; do
        lines+=("$line")
    done < "$file" || return 1

    [ "${#lines[@]}" -eq 5 ] || return 1
    [ "${lines[0]}" = 'schema = 1' ] || return 1
    [ -z "${lines[1]}" ] || return 1
    [ "${lines[2]}" = '[selection]' ] || return 1

    case "${lines[3]}" in
        'profile = "'*'"')
            profile=${lines[3]#'profile = "'}
            profile=${profile%'"'}
            [ "${lines[3]}" = "profile = \"${profile}\"" ] || return 1
            ;;
        'modules = '*)
            base_value=${lines[3]#'modules = '}
            dotfiles_config_parse_array "$base_value" || return 1
            modules=$DOTFILES_CONFIG_PARSED_ARRAY
            [ -n "$modules" ] || return 1
            ;;
        *) return 1 ;;
    esac

    case "${lines[4]}" in
        'additional_modules = '*)
            additional_value=${lines[4]#'additional_modules = '}
            dotfiles_config_parse_array "$additional_value" || return 1
            additional=$DOTFILES_CONFIG_PARSED_ARRAY
            ;;
        *) return 1 ;;
    esac

    dotfiles_config_validate_intent "$profile" "$modules" "$additional" >/dev/null 2>&1 || return 1
    dotfiles_config_build_body "$profile" "$modules" "$additional"
    actual_body=$(< "$file") || return 1
    [ "$actual_body" = "$DOTFILES_CONFIG_BODY" ] || return 1
    byte_count=$(LC_ALL=C wc -c < "$file") || return 1
    byte_count=${byte_count//[[:space:]]/}
    expected_size=$((${#DOTFILES_CONFIG_BODY} + 1))
    [ "$byte_count" -eq "$expected_size" ] 2>/dev/null || return 1

    DOTFILES_CONFIG_PARSED_PROFILE=$profile
    DOTFILES_CONFIG_PARSED_MODULES=$modules
    DOTFILES_CONFIG_PARSED_ADDITIONAL=$additional
}

dotfiles_config_stat_owner() {
    if stat -f '%u' "$1" >/dev/null 2>&1; then
        stat -f '%u' "$1"
    else
        stat -c '%u' "$1" 2>/dev/null
    fi
}

dotfiles_config_stat_mode() {
    if stat -f '%Lp' "$1" >/dev/null 2>&1; then
        stat -f '%Lp' "$1"
    else
        stat -c '%a' "$1" 2>/dev/null
    fi
}

dotfiles_config_stat_identity() {
    if stat -f '%d:%i' "$1" >/dev/null 2>&1; then
        stat -f '%d:%i' "$1"
    else
        stat -c '%d:%i' "$1" 2>/dev/null
    fi
}

dotfiles_config_stat_device() {
    if stat -f '%d' "$1" >/dev/null 2>&1; then
        stat -f '%d' "$1"
    else
        stat -c '%d' "$1" 2>/dev/null
    fi
}

dotfiles_config_stat_followed_inode() {
    if stat -f '%i' "$1" >/dev/null 2>&1; then
        stat -f '%i' "$1"
    else
        stat -L -c '%i' "$1" 2>/dev/null
    fi
}

dotfiles_config_path_is_lexically_safe() {
    local path=$1
    local newline=$'\n'
    local carriage_return=$'\r'

    case "$path" in
        /*) ;;
        *) return 1 ;;
    esac
    [ "$path" != / ] || return 1
    case "$path" in
        *//*|*/./*|*/../*|*/.|*/..|*/) return 1 ;;
        *';'*|*'|'*|*'&'*|*'<'*|*'>'*|*'`'*|*'$'*|*'~'*|*'('*|*')'*|*'{'*|*'}'*|*'['*|*']'*|*'*'*|*'?'*|*'!'*|*'"'*|*"'"*|*'\'*) return 1 ;;
    esac
    case "$path" in
        *"$newline"*|*"$carriage_return"*) return 1 ;;
    esac
    if LC_ALL=C printf '%s' "$path" | LC_ALL=C grep -q '[[:cntrl:]]'; then
        return 1
    fi
}

dotfiles_config_real_directory_is_safe() {
    local path=$1
    local owner
    local resolved

    [ ! -L "$path" ] || return 1
    [ -d "$path" ] || return 1
    owner=$(dotfiles_config_stat_owner "$path") || return 1
    [ "$owner" = "$(id -u)" ] || return 1
    resolved=$(CDPATH= cd -- "$path" 2>/dev/null && pwd -P) || return 1
    [ "$resolved" = "$path" ] || return 1
}

dotfiles_config_path_is_outside_project() {
    local path=$1
    local project

    project=$(CDPATH= cd -- "$PROJECT_ROOT" 2>/dev/null && pwd -P) || return 1
    case "${path}/" in
        "${project}/"*) return 1 ;;
    esac
}

dotfiles_config_storage_error() {
    printf 'error: unsafe local selection storage under %s\n' "$DOTFILES_CONFIG_ROOT_LABEL" >&2
    printf 'Use a current-user-owned, real, writable configuration directory outside the repository.\n' >&2
}

dotfiles_config_state_error() {
    printf 'error: local selection at %s/dotfiles/active-selection.toml is unsafe or invalid\n' "$DOTFILES_CONFIG_ROOT_LABEL" >&2
    printf 'Preserve or move it aside, or repair its path and permissions, then rerun dotfiles config set.\n' >&2
}

dotfiles_config_lock_error() {
    printf 'error: local selection writer lock exists at %s/dotfiles/active-selection.lock\n' "$DOTFILES_CONFIG_ROOT_LABEL" >&2
    printf 'Confirm that no writer is active before removing the lock manually.\n' >&2
}

dotfiles_config_uncertain_error() {
    printf 'error: the local selection update could not be confirmed\n' >&2
    printf 'Run dotfiles config doctor before relying on the saved selection.\n' >&2
}

dotfiles_config_require_tools() {
    local tool

    for tool in chmod cmp cp grep id mkdir mktemp mv rm rmdir stat sync uname wc; do
        command -v "$tool" >/dev/null 2>&1 || {
            printf 'error: local selection state requirements are unavailable\n' >&2
            return 4
        }
    done
}

dotfiles_config_derive_root() {
    local private_root=$1

    if [ -n "$private_root" ]; then
        DOTFILES_CONFIG_ROOT=$private_root
        DOTFILES_CONFIG_ROOT_LABEL='$XDG_CONFIG_HOME'
    elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
        DOTFILES_CONFIG_ROOT=$XDG_CONFIG_HOME
        DOTFILES_CONFIG_ROOT_LABEL='$XDG_CONFIG_HOME'
    else
        [ -n "${HOME:-}" ] || {
            DOTFILES_CONFIG_ROOT_LABEL='$HOME/.config'
            dotfiles_config_storage_error
            return 3
        }
        DOTFILES_CONFIG_ROOT="${HOME}/.config"
        DOTFILES_CONFIG_ROOT_LABEL='$HOME/.config'
    fi

    dotfiles_config_path_is_lexically_safe "$DOTFILES_CONFIG_ROOT" || {
        dotfiles_config_storage_error
        return 3
    }
    dotfiles_config_path_is_outside_project "$DOTFILES_CONFIG_ROOT" || {
        dotfiles_config_storage_error
        return 3
    }
}

dotfiles_config_prepare_root() {
    local parent
    local created=0

    if [ -e "$DOTFILES_CONFIG_ROOT" ] || [ -L "$DOTFILES_CONFIG_ROOT" ]; then
        dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_ROOT" || {
            dotfiles_config_storage_error
            return 3
        }
    else
        parent=${DOTFILES_CONFIG_ROOT%/*}
        [ -n "$parent" ] || parent=/
        dotfiles_config_real_directory_is_safe "$parent" || {
            dotfiles_config_storage_error
            return 3
        }
        umask 077
        mkdir "$DOTFILES_CONFIG_ROOT" 2>/dev/null || {
            dotfiles_config_uncertain_error
            return 4
        }
        created=1
        chmod 700 "$DOTFILES_CONFIG_ROOT" 2>/dev/null || {
            dotfiles_config_uncertain_error
            return 4
        }
        dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_ROOT" || {
            dotfiles_config_storage_error
            return 3
        }
        [ "$(dotfiles_config_stat_mode "$DOTFILES_CONFIG_ROOT")" = 700 ] || {
            dotfiles_config_storage_error
            return 3
        }
    fi
    [ -w "$DOTFILES_CONFIG_ROOT" ] && [ -x "$DOTFILES_CONFIG_ROOT" ] || {
        dotfiles_config_storage_error
        return 3
    }
    [ "$created" -eq 0 ] || return 0
}

dotfiles_config_set_paths() {
    DOTFILES_CONFIG_DIRECTORY="${DOTFILES_CONFIG_ROOT}/dotfiles"
    DOTFILES_CONFIG_STATE_PATH="${DOTFILES_CONFIG_DIRECTORY}/active-selection.toml"
    DOTFILES_CONFIG_LOCK_PATH="${DOTFILES_CONFIG_DIRECTORY}/active-selection.lock"
}

dotfiles_config_prepare_directory() {
    dotfiles_config_set_paths

    if [ -e "$DOTFILES_CONFIG_DIRECTORY" ] || [ -L "$DOTFILES_CONFIG_DIRECTORY" ]; then
        dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_DIRECTORY" || {
            dotfiles_config_storage_error
            return 3
        }
    else
        umask 077
        mkdir "$DOTFILES_CONFIG_DIRECTORY" 2>/dev/null || {
            dotfiles_config_uncertain_error
            return 4
        }
        chmod 700 "$DOTFILES_CONFIG_DIRECTORY" 2>/dev/null || {
            dotfiles_config_uncertain_error
            return 4
        }
    fi
    dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_DIRECTORY" || {
        dotfiles_config_storage_error
        return 3
    }
    [ "$(dotfiles_config_stat_mode "$DOTFILES_CONFIG_DIRECTORY")" = 700 ] || {
        dotfiles_config_storage_error
        return 3
    }
    [ -w "$DOTFILES_CONFIG_DIRECTORY" ] && [ -x "$DOTFILES_CONFIG_DIRECTORY" ] || {
        dotfiles_config_storage_error
        return 3
    }
}

dotfiles_config_validate_state_path() {
    local owner
    local mode

    if [ ! -e "$DOTFILES_CONFIG_STATE_PATH" ] && [ ! -L "$DOTFILES_CONFIG_STATE_PATH" ]; then
        return 0
    fi
    [ ! -L "$DOTFILES_CONFIG_STATE_PATH" ] || return 1
    [ -f "$DOTFILES_CONFIG_STATE_PATH" ] || return 1
    [ -r "$DOTFILES_CONFIG_STATE_PATH" ] || return 1
    owner=$(dotfiles_config_stat_owner "$DOTFILES_CONFIG_STATE_PATH") || return 1
    mode=$(dotfiles_config_stat_mode "$DOTFILES_CONFIG_STATE_PATH") || return 1
    [ "$owner" = "$(id -u)" ] || return 1
    [ "$mode" = 600 ] || return 1
}

dotfiles_config_revalidate_directories() {
    dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_ROOT" || return 1
    dotfiles_config_path_is_outside_project "$DOTFILES_CONFIG_ROOT" || return 1
    dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_DIRECTORY" || return 1
    [ "$(dotfiles_config_stat_mode "$DOTFILES_CONFIG_DIRECTORY")" = 700 ] || return 1
    [ -w "$DOTFILES_CONFIG_DIRECTORY" ] && [ -x "$DOTFILES_CONFIG_DIRECTORY" ] || return 1
}

dotfiles_config_revalidate_tree() {
    dotfiles_config_revalidate_directories || return 1
    dotfiles_config_validate_state_path
}

dotfiles_config_hook() {
    local hook_key=$1
    local variable_name="DOTFILES_CONFIG_TEST_${hook_key}"
    local function_name=

    [ -n "${DOTFILES_CONFIG_PRIVATE_ROOT_ACTIVE:-}" ] || return 0
    function_name=${!variable_name:-}
    [ -n "$function_name" ] || return 0
    case "$function_name" in
        [a-zA-Z_][a-zA-Z0-9_]*) ;;
        *) return 4 ;;
    esac
    declare -F "$function_name" >/dev/null 2>&1 || return 4
    "$function_name"
}

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
