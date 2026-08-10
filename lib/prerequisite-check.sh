#!/usr/bin/env bash

# Read-only prerequisite checks, separate from catalog parsing and planning.

prerequisite_sanitize_path() {
    local_path=$1
    case ${HOME:-} in
        /*)
            case "$local_path" in
                "$HOME") printf '$HOME\n' ;;
                "$HOME"/*) printf '$HOME/%s\n' "${local_path#"$HOME"/}" ;;
                *)
                    if command -v realpath >/dev/null 2>&1 && local_home_resolved=$(realpath "$HOME" 2>/dev/null) && local_path_resolved=$(realpath "$local_path" 2>/dev/null); then
                        case "$local_path_resolved" in
                            "$local_home_resolved") printf '$HOME\n' ;;
                            "$local_home_resolved"/*) printf '$HOME/%s\n' "${local_path_resolved#"$local_home_resolved"/}" ;;
                            *) printf '%s\n' "$local_path" ;;
                        esac
                    else
                        printf '%s\n' "$local_path"
                    fi
                    ;;
            esac
            ;;
        *) printf '%s\n' "$local_path" ;;
    esac
}

prerequisite_valid_root() {
    local_root=$1
    case "$local_root" in /*) ;; *) return 1 ;; esac
    case "$local_root" in *':'*|*'~'*|*'$'*|*'*'*|*'?'*|*'['*|*']'*|*'`'*|*'\'*) return 1 ;; esac
    if printf '%s' "$local_root" | LC_ALL=C grep '[[:cntrl:]]' >/dev/null 2>&1; then
        return 1
    fi
    case "/${local_root#/}/" in *'/./'*|*'/../'*) return 1 ;; esac
}

prerequisite_valid_path_entry() {
    local_entry=$1
    case "$local_entry" in /*) ;; *) return 1 ;; esac
    if printf '%s' "$local_entry" | LC_ALL=C grep '[[:cntrl:]]' >/dev/null 2>&1; then
        return 1
    fi
    [ "$local_entry" = / ] && return 0
    case "/${local_entry#/}/" in *'//'*|*'/./'*|*'/../'*) return 1 ;; esac
}

prerequisite_normalize_root() {
    printf '%s\n' "$1" | awk '{ value=$0; gsub(/\/+/, "/", value); if (value != "/") sub(/\/+$/, "", value); print value }'
}

prerequisite_add_root() {
    local_origin=$1
    local_value=$(prerequisite_normalize_root "$2")
    local_explicit=$3
    if ! prerequisite_valid_root "$local_value"; then
        if [ "$local_explicit" -eq 1 ]; then
            printf 'error: invalid explicit artifact root %s (%s): expected a literal absolute path\n' "$local_origin" "$(prerequisite_sanitize_path "$local_value")" >&2
            return 3
        fi
        printf 'notice: ignored invalid artifact root %s (%s)\n' "$local_origin" "$(prerequisite_sanitize_path "$local_value")" >&2
        return 0
    fi
    case "$PREREQUISITE_ROOT_PATHS" in
        "$local_value"|"$local_value"$'\n'*|*$'\n'"$local_value"|*$'\n'"$local_value"$'\n'*) return 0 ;;
    esac
    if ! local_resolved=$(realpath "$local_value" 2>/dev/null) || [ ! -d "$local_resolved" ]; then
        if [ "$local_explicit" -eq 1 ]; then
            printf 'error: explicit artifact root %s cannot be resolved: %s\n' "$local_origin" "$(prerequisite_sanitize_path "$local_value")" >&2
            return 3
        fi
        printf 'notice: ignored unavailable artifact root %s (%s)\n' "$local_origin" "$(prerequisite_sanitize_path "$local_value")" >&2
        return 0
    fi
    PREREQUISITE_ROOT_PATHS="${PREREQUISITE_ROOT_PATHS}${PREREQUISITE_ROOT_PATHS:+
}${local_value}"
    PREREQUISITE_ROOT_RESOLVED="${PREREQUISITE_ROOT_RESOLVED}${PREREQUISITE_ROOT_RESOLVED:+
}${local_resolved}"
    PREREQUISITE_ROOT_LABELS="${PREREQUISITE_ROOT_LABELS}${PREREQUISITE_ROOT_LABELS:+
}${local_origin}=$(prerequisite_sanitize_path "$local_value")"
}

prerequisite_add_path_list() {
    local_list_origin=$1
    local_list_value=$2
    local_list_explicit=$3
    local_position=1
    local_remaining=$local_list_value
    while :; do
        case "$local_remaining" in
            *:*) local_entry=${local_remaining%%:*}; local_remaining=${local_remaining#*:}; local_more=1 ;;
            *) local_entry=$local_remaining; local_more=0 ;;
        esac
        if [ -z "$local_entry" ]; then
            if [ "$local_list_explicit" -eq 1 ]; then
                printf 'error: explicit artifact root %s[%s] is empty\n' "$local_list_origin" "$local_position" >&2
                return 3
            fi
            printf 'notice: ignored empty artifact root %s[%s]\n' "$local_list_origin" "$local_position" >&2
        else
            prerequisite_add_root "${local_list_origin}[${local_position}]" "$local_entry" "$local_list_explicit" || return $?
        fi
        [ "$local_more" -eq 1 ] || break
        local_position=$((local_position + 1))
    done
}

prerequisite_build_roots() {
    command -v realpath >/dev/null 2>&1 || {
        printf 'error: realpath is required for artifact checks\n' >&2
        return 4
    }
    PREREQUISITE_ROOT_PATHS=
    PREREQUISITE_ROOT_RESOLVED=
    PREREQUISITE_ROOT_LABELS=
    if [ "${DOTFILES_SHARE_ROOTS+x}" = x ]; then
        prerequisite_add_path_list DOTFILES_SHARE_ROOTS "$DOTFILES_SHARE_ROOTS" 1 || return $?
    fi
    if [ -n "${XDG_DATA_HOME:-}" ] && prerequisite_valid_root "$(prerequisite_normalize_root "$XDG_DATA_HOME")"; then
        prerequisite_add_root XDG_DATA_HOME "$XDG_DATA_HOME" 0 || return $?
    else
        if [ "${XDG_DATA_HOME+x}" = x ]; then
            printf 'notice: XDG_DATA_HOME is invalid or empty; considering HOME fallback\n' >&2
        fi
        if [ -n "${HOME:-}" ] && prerequisite_valid_root "$(prerequisite_normalize_root "$HOME")"; then
            prerequisite_add_root HOME-fallback "${HOME}/.local/share" 0 || return $?
        else
            printf 'notice: HOME is missing or invalid; no user data root is available\n' >&2
        fi
    fi
    if [ "${XDG_DATA_DIRS+x}" = x ]; then
        prerequisite_add_path_list XDG_DATA_DIRS "$XDG_DATA_DIRS" 0 || return $?
    fi
    prerequisite_add_root system-local /usr/local/share 0 || return $?
    prerequisite_add_root system /usr/share 0 || return $?
}

prerequisite_command_present() {
    local_name=$1
    local_path_list=${PATH:-}
    while :; do
        case "$local_path_list" in
            *:*) local_directory=${local_path_list%%:*}; local_path_list=${local_path_list#*:}; local_more=1 ;;
            *) local_directory=$local_path_list; local_more=0 ;;
        esac
        if prerequisite_valid_path_entry "$local_directory" &&
           [ -f "${local_directory}/${local_name}" ] &&
           [ -x "${local_directory}/${local_name}" ]; then
            return 0
        fi
        [ "$local_more" -eq 1 ] || break
    done
    return 1
}

prerequisite_artifact_present() {
    local_relative=${1#share:}
    local_paths=$PREREQUISITE_ROOT_PATHS
    local_resolved_roots=$PREREQUISITE_ROOT_RESOLVED
    while [ -n "$local_paths" ]; do
        local_root=${local_paths%%$'\n'*}
        local_resolved_root=${local_resolved_roots%%$'\n'*}
        if [ "$local_paths" = "$local_root" ]; then local_paths=; else local_paths=${local_paths#*$'\n'}; fi
        if [ "$local_resolved_roots" = "$local_resolved_root" ]; then local_resolved_roots=; else local_resolved_roots=${local_resolved_roots#*$'\n'}; fi
        local_candidate="${local_root}/${local_relative}"
        if local_resolved_candidate=$(realpath "$local_candidate" 2>/dev/null) && [ -f "$local_resolved_candidate" ]; then
            case "$local_resolved_root" in
                /) return 0 ;;
                *) case "$local_resolved_candidate" in "$local_resolved_root"/*) return 0 ;; esac ;;
            esac
        fi
    done
    return 1
}

prerequisite_check_records() {
    local_records=$1
    while IFS=$'\t' read -r local_module local_kind local_identifier; do
        [ -n "$local_module" ] || continue
        if [ "$local_kind" = application ]; then
            printf 'error: module %s application %s cannot be checked: application prerequisite checking is not implemented\n' "$local_module" "$local_identifier" >&2
            return 4
        fi
    done <<< "$local_records"
    if [ -z "$local_records" ]; then
        printf 'No prerequisites declared.\n'
        return 0
    fi
    case "$local_records" in *$'\tartifact\t'*) prerequisite_build_roots || return $? ;; esac
    local_missing=0
    while IFS=$'\t' read -r local_module local_kind local_identifier; do
        [ -n "$local_module" ] || continue
        case "$local_kind" in
            command) prerequisite_command_present "$local_identifier" && local_present=1 || local_present=0 ;;
            artifact)
                printf 'roots: %s artifact %s — %s\n' "$local_module" "$local_identifier" "$(printf '%s' "$PREREQUISITE_ROOT_LABELS" | tr '\n' ';')"
                prerequisite_artifact_present "$local_identifier" && local_present=1 || local_present=0
                ;;
            *) printf 'error: unsupported prerequisite kind %s for module %s\n' "$local_kind" "$local_module" >&2; return 4 ;;
        esac
        if [ "$local_present" -eq 1 ]; then
            printf 'present: %s %s %s\n' "$local_module" "$local_kind" "$local_identifier"
        else
            printf 'missing: %s %s %s — provide it outside this project\n' "$local_module" "$local_kind" "$local_identifier"
            local_missing=1
        fi
    done <<< "$local_records"
    [ "$local_missing" -eq 0 ] || return 5
}
