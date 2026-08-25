# Source-only portable storage, path safety, diagnostics, tools, and test hooks.

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

dotfiles_config_stat_followed_size() {
    if stat -f '%z' "$1" >/dev/null 2>&1; then
        stat -f '%z' "$1"
    else
        stat -L -c '%s' "$1" 2>/dev/null
    fi
}

dotfiles_config_stat_links() {
    if stat -f '%l' "$1" >/dev/null 2>&1; then
        stat -f '%l' "$1"
    else
        stat -c '%h' "$1" 2>/dev/null
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
    if [ "${DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT:-}" = doctor ]; then
        printf 'Preserve or move unsafe entries aside, repair the configuration path, then rerun dotfiles config doctor.\n' >&2
    elif [ "${DOTFILES_CONFIG_OPERATION_MODE:-write}" = read ]; then
        printf 'Use a current-user-owned, real configuration directory outside the repository, or pass --profile or --modules.\n' >&2
    else
        printf 'Use a current-user-owned, real, writable configuration directory outside the repository.\n' >&2
    fi
}

dotfiles_config_state_error() {
    printf 'error: local selection at %s/dotfiles/active-selection.toml is unsafe or invalid\n' "$DOTFILES_CONFIG_ROOT_LABEL" >&2
    if [ "${DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT:-}" = doctor ]; then
        printf 'Preserve or move it aside, repair its path and permissions, then run dotfiles config set or dotfiles config interactive.\n' >&2
    elif [ "${DOTFILES_CONFIG_OPERATION_MODE:-write}" = read ]; then
        printf 'Preserve or move it aside, repair it with dotfiles config set, or pass --profile or --modules.\n' >&2
    else
        printf 'Preserve or move it aside, or repair its path and permissions, then rerun dotfiles config set.\n' >&2
    fi
}

dotfiles_config_missing_state_error() {
    printf 'error: no local selection is configured under %s/dotfiles\n' "$DOTFILES_CONFIG_ROOT_LABEL" >&2
    if [ "${DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT:-}" = doctor ]; then
        printf 'Run dotfiles config set or dotfiles config interactive.\n' >&2
    else
        printf 'Run dotfiles config set or pass --profile or --modules.\n' >&2
    fi
}

dotfiles_config_read_drift_error() {
    printf 'error: local selection changed or was replaced while being read\n' >&2
    if [ "${DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT:-}" = doctor ]; then
        printf 'Rerun dotfiles config doctor.\n' >&2
    else
        printf 'Rerun the command or pass --profile or --modules.\n' >&2
    fi
}

dotfiles_config_read_handle_error() {
    printf 'error: local selection read handle is unavailable\n' >&2
    if [ "${DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT:-}" = doctor ]; then
        printf 'Close inherited file descriptors and rerun dotfiles config doctor.\n' >&2
    else
        printf 'Close inherited file descriptors or pass --profile or --modules.\n' >&2
    fi
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

dotfiles_config_require_read_tools() {
    local tool

    for tool in cat grep id stat wc; do
        command -v "$tool" >/dev/null 2>&1 || {
            printf 'error: local selection read requirements are unavailable\n' >&2
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
    [ "$(dotfiles_config_stat_links "$DOTFILES_CONFIG_STATE_PATH")" = 1 ] || return 1
}

dotfiles_config_validate_read_directories() {
    dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_ROOT" || return 1
    dotfiles_config_path_is_outside_project "$DOTFILES_CONFIG_ROOT" || return 1
    [ -r "$DOTFILES_CONFIG_ROOT" ] && [ -x "$DOTFILES_CONFIG_ROOT" ] || return 1
    dotfiles_config_real_directory_is_safe "$DOTFILES_CONFIG_DIRECTORY" || return 1
    [ "$(dotfiles_config_stat_mode "$DOTFILES_CONFIG_DIRECTORY")" = 700 ] || return 1
    [ -r "$DOTFILES_CONFIG_DIRECTORY" ] && [ -x "$DOTFILES_CONFIG_DIRECTORY" ] || return 1
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
