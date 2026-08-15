#!/usr/bin/env bash

# Internal, read-only selected-source renderer for future plan and apply paths.
# Arguments: output directory, profile ID, module IDs, added module IDs, platform.

dotfiles_render_cleanup() {
    local local_cleanup_temp
    if [ -n "${DOTFILES_RENDER_OUTPUT_TEMP_LIST:-}" ] && [ -f "$DOTFILES_RENDER_OUTPUT_TEMP_LIST" ]; then
        while IFS= read -r -d '' local_cleanup_temp; do
            [ -z "$local_cleanup_temp" ] || rm -f -- "$local_cleanup_temp"
        done < "$DOTFILES_RENDER_OUTPUT_TEMP_LIST"
    fi
    [ -z "${DOTFILES_RENDER_PRIVATE:-}" ] || rm -rf -- "$DOTFILES_RENDER_PRIVATE"
}

dotfiles_render_scalar_safe() {
    local local_value=$1
    case "$local_value" in *$'\n'*|*$'\r'*) return 1 ;; esac
    ! printf '%s' "$local_value" | LC_ALL=C grep '[[:cntrl:]]' >/dev/null 2>&1
}

dotfiles_render_toml_string() {
    local local_value=$1
    dotfiles_render_scalar_safe "$local_value" || return 3
    local_value=${local_value//\\/\\\\}
    local_value=${local_value//\"/\\\"}
    printf '"%s"' "$local_value"
}

dotfiles_render_has_value() {
    local local_wanted=$1
    shift
    local local_value
    for local_value in "$@"; do
        [ "$local_value" = "$local_wanted" ] && return 0
    done
    return 1
}

dotfiles_render_prepare_target() {
    local local_root=$1
    local local_target=$2
    local local_current=$local_root
    local local_remaining=$local_target
    local local_segment

    case "$local_target" in ""|/*|*'//'*) return 1 ;; esac
    case "/${local_target}/" in *'/./'*|*'/../'*) return 1 ;; esac

    while case "$local_remaining" in */*) true ;; *) false ;; esac; do
        local_segment=${local_remaining%%/*}
        local_remaining=${local_remaining#*/}
        local_current="${local_current}/${local_segment}"
        [ ! -L "$local_current" ] || return 1
        if [ ! -e "$local_current" ]; then
            mkdir "$local_current" || return 1
        fi
        [ -d "$local_current" ] || return 1
    done

    local_current="${local_current}/${local_remaining}"
    [ ! -L "$local_current" ] || return 1
    [ ! -e "$local_current" ] || [ -f "$local_current" ] || return 1
}

dotfiles_render_selection() {
    if [ "$#" -ne 5 ]; then
        printf 'error: internal renderer requires output, profile, modules, additions, and platform\n' >&2
        return 2
    fi
    dotfiles_render_selection_internal "" "$@"
}

dotfiles_render_selection_then() {
    if [ "$#" -ne 6 ]; then
        printf 'error: internal renderer callback requires a function and render arguments\n' >&2
        return 2
    fi
    if ! declare -F "$1" >/dev/null 2>&1; then
        printf 'error: internal renderer callback is unavailable\n' >&2
        return 4
    fi
    dotfiles_render_selection_internal "$@"
}

dotfiles_render_selection_internal() (
    if [ "$#" -ne 6 ]; then
        printf 'error: invalid internal renderer invocation\n' >&2
        return 2
    fi

    local local_callback=$1
    local local_output=$2
    local local_profile=$3
    local local_modules_input=$4
    local local_additional=$5
    local local_platform=$6
    local local_output_resolved
    local local_home_resolved=
    local local_source_resolved
    local local_temp_parent=${TMPDIR:-/tmp}
    local local_private=
    local local_context
    local local_selection_file
    local local_staging
    local local_backup
    local local_render_records
    local local_prerequisite_records
    local local_status
    local local_kind local_a local_b local_c local_extra
    local local_previous_target=
    local local_artifact=
    local local_artifact_count=0
    local local_index
    local local_source_file
    local local_target_file
    local local_target_parent
    local local_backup_file
    local local_publish_temp
    local local_rollback_index
    local local_rollback_temp
    local local_rollback_failed
    local local_error_file
    local local_render_chezmoi=${DOTFILES_RENDER_CHEZMOI_BIN:-$CHEZMOI_BIN}
    local local_duplicate
    local LC_ALL=C
    local -a local_resolved_modules=()
    local -a local_source_modules=()
    local -a local_sources=()
    local -a local_targets=()
    local -a local_target_existed=()
    local -a local_publish_temps=()

    if [ -n "$local_profile" ] && [ -n "$local_modules_input" ]; then
        printf 'error: internal renderer selection is mutually exclusive\n' >&2
        return 2
    fi
    if [ -z "$local_profile" ] && [ -z "$local_modules_input" ]; then
        printf 'error: internal renderer requires a profile or modules\n' >&2
        return 2
    fi
    validate_platform "$local_platform" >/dev/null || return $?

    case "$local_output" in /*) ;; *) printf 'error: internal render output must be an absolute directory\n' >&2; return 3 ;; esac
    [ -d "$local_output" ] && [ ! -L "$local_output" ] || {
        printf 'error: internal render output must be an existing regular directory\n' >&2
        return 3
    }
    if ! local_output_resolved=$(CDPATH= cd -- "$local_output" 2>/dev/null && pwd -P); then
        printf 'error: internal render output cannot be resolved\n' >&2
        return 3
    fi
    if [ -n "${HOME:-}" ] && [ -d "$HOME" ] && local_home_resolved=$(CDPATH= cd -- "$HOME" 2>/dev/null && pwd -P); then
        case "$local_output_resolved" in
            "$local_home_resolved"|"$local_home_resolved"/*)
                printf 'error: internal rendering refuses a home-directory output\n' >&2
                return 3
                ;;
        esac
    fi
    if ! local_source_resolved=$(CDPATH= cd -- "$SOURCE_DIR" 2>/dev/null && pwd -P); then
        printf 'error: internal rendering source cannot be resolved\n' >&2
        return 3
    fi
    case "$local_output_resolved" in
        "$local_source_resolved"|"$local_source_resolved"/*)
            printf 'error: internal rendering refuses a repository output\n' >&2
            return 3
            ;;
    esac

    case "$local_temp_parent" in /*) ;; *) local_temp_parent=/tmp ;; esac
    umask 077
    if ! local_private=$(mktemp -d "${local_temp_parent%/}/dotfiles-render.XXXXXX"); then
        printf 'error: internal render context directory could not be created\n' >&2
        return 4
    fi
    DOTFILES_RENDER_PRIVATE=$local_private
    DOTFILES_RENDER_OUTPUT_TEMP_LIST="${local_private}/output-temps"
    trap dotfiles_render_cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    chmod 700 "$local_private" || return 4
    : > "$DOTFILES_RENDER_OUTPUT_TEMP_LIST" || return 4

    local_context="${local_private}/context.toml"
    local_selection_file="${local_private}/selection.tsv"
    local_staging="${local_private}/rendered"
    local_backup="${local_private}/previous"
    local_error_file="${local_private}/error.log"
    mkdir "$local_staging" "$local_backup" "${local_private}/destination" "${local_private}/cache" || return 4

    if local_render_records=$(run_catalog render_inputs "$local_platform" 0 "" "$local_profile" "$local_modules_input" "$local_additional"); then
        :
    else
        return $?
    fi

    while IFS=$'\t' read -r local_kind local_a local_b local_c local_extra; do
        [ -n "$local_kind" ] || continue
        case "$local_kind" in
            module)
                local_duplicate=0
                if [ "${#local_resolved_modules[@]}" -gt 0 ] && dotfiles_render_has_value "$local_a" "${local_resolved_modules[@]}"; then
                    local_duplicate=1
                fi
                if [ -z "$local_a" ] || [ -n "$local_b" ] || [ -n "$local_c" ] || [ -n "$local_extra" ] ||
                   ! printf '%s' "$local_a" | grep -Eq '^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$' ||
                   [ "$local_duplicate" -ne 0 ]; then
                    printf 'error: invalid resolved module render input\n' >&2
                    return 3
                fi
                local_resolved_modules[${#local_resolved_modules[@]}]=$local_a
                ;;
            source)
                local_duplicate=0
                if [ "${#local_sources[@]}" -gt 0 ] && dotfiles_render_has_value "$local_b" "${local_sources[@]}"; then
                    local_duplicate=1
                fi
                if [ -z "$local_a" ] || [ -z "$local_b" ] || [ -z "$local_c" ] || [ -n "$local_extra" ] ||
                   ! dotfiles_render_has_value "$local_a" "${local_resolved_modules[@]}" ||
                   [ "$local_duplicate" -ne 0 ] ||
                   ! dotfiles_render_scalar_safe "$local_b" || ! dotfiles_render_scalar_safe "$local_c"; then
                    printf 'error: invalid selected source render input\n' >&2
                    return 3
                fi
                if [ -n "$local_previous_target" ] && [[ "$local_c" < "$local_previous_target" || "$local_c" = "$local_previous_target" ]]; then
                    printf 'error: selected sources are not in unique target order\n' >&2
                    return 3
                fi
                local_source_file="${SOURCE_DIR}/${local_b}"
                if [ ! -f "$local_source_file" ] || [ -L "$local_source_file" ]; then
                    printf 'error: a selected chezmoi source is unavailable\n' >&2
                    return 3
                fi
                local_source_modules[${#local_source_modules[@]}]=$local_a
                local_sources[${#local_sources[@]}]=$local_b
                local_targets[${#local_targets[@]}]=$local_c
                local_previous_target=$local_c
                ;;
            *)
                printf 'error: unknown internal render input field\n' >&2
                return 3
                ;;
        esac
    done <<< "$local_render_records"

    {
        for local_index in "${!local_sources[@]}"; do
            printf '%s\t%s\t%s\n' "${local_source_modules[$local_index]}" \
                "${local_sources[$local_index]}" "${local_targets[$local_index]}"
        done
    } > "$local_selection_file"
    chmod 600 "$local_selection_file" || return 4

    if [ ! -f "$PREREQUISITE_PROGRAM" ]; then
        printf 'error: prerequisite checker implementation is missing\n' >&2
        return 4
    fi
    if ! declare -F prerequisite_check_records >/dev/null 2>&1; then
        # shellcheck source=prerequisite-check.sh
        source "$PREREQUISITE_PROGRAM"
    fi
    if local_prerequisite_records=$(run_catalog prerequisites "$local_platform" 0 "" "$local_profile" "$local_modules_input" "$local_additional"); then
        :
    else
        return $?
    fi
    if prerequisite_check_records "$local_prerequisite_records" >"${local_private}/prerequisites.log" 2>"$local_error_file"; then
        :
    else
        local_status=$?
        printf 'error: selected rendering prerequisites are not satisfied\n' >&2
        return "$local_status"
    fi
    if [ "${PREREQUISITE_ARTIFACT_FACTS_INVALID:-0}" -ne 0 ]; then
        printf 'error: selected artifact path is unsafe for rendering\n' >&2
        return 3
    fi

    while IFS=$'\t' read -r local_a local_b local_c local_extra; do
        [ -n "$local_a" ] || continue
        if [ -z "$local_b" ] || [ -z "$local_c" ] || [ -n "$local_extra" ] ||
           ! dotfiles_render_has_value "$local_a" "${local_resolved_modules[@]}" ||
           ! dotfiles_render_scalar_safe "$local_c"; then
            printf 'error: invalid selected artifact render fact\n' >&2
            return 3
        fi
        if [ "$local_a" = shell.zsh.autosuggestions ] && [ "$local_b" = share:zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
            local_artifact=$local_c
            local_artifact_count=$((local_artifact_count + 1))
        fi
    done <<< "${PREREQUISITE_ARTIFACT_FACTS:-}"

    if dotfiles_render_has_value shell.zsh.autosuggestions "${local_resolved_modules[@]}"; then
        if [ "$local_artifact_count" -ne 1 ]; then
            printf 'error: autosuggestions requires one canonical artifact fact\n' >&2
            return 3
        fi
    elif [ "$local_artifact_count" -ne 0 ]; then
        printf 'error: unselected autosuggestions artifact fact\n' >&2
        return 3
    fi

    {
        printf '[dotfiles_render]\n'
        printf 'schema = 1\n'
        printf 'platform = '
        dotfiles_render_toml_string "$local_platform" || return $?
        printf '\nmodules = ['
        for local_index in "${!local_resolved_modules[@]}"; do
            [ "$local_index" -eq 0 ] || printf ', '
            dotfiles_render_toml_string "${local_resolved_modules[$local_index]}" || return $?
        done
        printf ']\nsources = ['
        for local_index in "${!local_sources[@]}"; do
            [ "$local_index" -eq 0 ] || printf ', '
            dotfiles_render_toml_string "${local_sources[$local_index]}" || return $?
        done
        printf ']\n'
        if [ "$local_artifact_count" -eq 1 ]; then
            printf 'autosuggestions_artifact = '
            dotfiles_render_toml_string "$local_artifact" || return $?
            printf '\n'
        fi
    } > "$local_context"
    chmod 600 "$local_context" || return 4

    for local_index in "${!local_sources[@]}"; do
        local_target_file="${local_staging}/${local_targets[$local_index]}"
        mkdir -p "$(dirname -- "$local_target_file")" || return 4
        if "$local_render_chezmoi" --no-pager --no-tty --config /dev/null --config-format toml \
            --source "${SOURCE_DIR}/home" --destination "${local_private}/destination" \
            --cache "${local_private}/cache" --persistent-state "${local_private}/state.boltdb" \
            --refresh-externals=never --override-data-file "$local_context" \
            cat "${local_private}/destination/${local_targets[$local_index]}" > "$local_target_file" 2> "$local_error_file"; then
            :
        else
            printf 'error: read-only chezmoi rendering failed for a selected source\n' >&2
            return 4
        fi
    done

    for local_index in "${!local_targets[@]}"; do
        dotfiles_render_prepare_target "$local_output_resolved" "${local_targets[$local_index]}" 2>> "$local_error_file" || {
            printf 'error: internal render output target is unsafe\n' >&2
            return 3
        }
        local_target_file="${local_output_resolved}/${local_targets[$local_index]}"
        if [ -e "$local_target_file" ]; then
            local_target_existed[$local_index]=1
            local_backup_file="${local_backup}/${local_targets[$local_index]}"
            mkdir -p "$(dirname -- "$local_backup_file")" 2>> "$local_error_file" || return 4
            if ! cp -p -- "$local_target_file" "$local_backup_file" 2>> "$local_error_file"; then
                printf 'error: existing render output could not be staged for rollback\n' >&2
                return 4
            fi
        else
            local_target_existed[$local_index]=0
        fi
    done

    # Prepare every same-directory replacement before changing any target.
    for local_index in "${!local_targets[@]}"; do
        local_target_file="${local_output_resolved}/${local_targets[$local_index]}"
        local_target_parent=$(dirname -- "$local_target_file")
        if ! local_publish_temp=$(mktemp "${local_target_parent}/.dotfiles-render.XXXXXX" 2>> "$local_error_file"); then
            printf 'error: complete rendered target set could not be staged\n' >&2
            return 4
        fi
        if ! printf '%s\0' "$local_publish_temp" >> "$DOTFILES_RENDER_OUTPUT_TEMP_LIST"; then
            rm -f -- "$local_publish_temp"
            return 4
        fi
        local_publish_temps[$local_index]=$local_publish_temp
        if ! cp -- "${local_staging}/${local_targets[$local_index]}" "$local_publish_temp" 2>> "$local_error_file"; then
            printf 'error: complete rendered target set could not be staged\n' >&2
            return 4
        fi
    done

    for local_index in "${!local_targets[@]}"; do
        local_target_file="${local_output_resolved}/${local_targets[$local_index]}"
        local_publish_temp=${local_publish_temps[$local_index]}
        if dotfiles_render_prepare_target "$local_output_resolved" "${local_targets[$local_index]}" 2>> "$local_error_file" &&
           mv -f -- "$local_publish_temp" "$local_target_file" 2>> "$local_error_file"; then
            local_publish_temps[$local_index]=
            continue
        fi

        local_rollback_failed=0
        if [ -e "$local_publish_temp" ]; then
            local_rollback_index=$((local_index - 1))
        else
            local_rollback_index=$local_index
        fi
        while [ "$local_rollback_index" -ge 0 ]; do
            local_target_file="${local_output_resolved}/${local_targets[$local_rollback_index]}"
            if [ "${local_target_existed[$local_rollback_index]}" -eq 1 ]; then
                local_target_parent=$(dirname -- "$local_target_file")
                local_rollback_temp=
                if local_rollback_temp=$(mktemp "${local_target_parent}/.dotfiles-render-rollback.XXXXXX" 2>> "$local_error_file") &&
                   printf '%s\0' "$local_rollback_temp" >> "$DOTFILES_RENDER_OUTPUT_TEMP_LIST" &&
                   cp -p -- "${local_backup}/${local_targets[$local_rollback_index]}" "$local_rollback_temp" 2>> "$local_error_file" &&
                   mv -f -- "$local_rollback_temp" "$local_target_file" 2>> "$local_error_file"; then
                    :
                else
                    local_rollback_failed=1
                    [ -z "$local_rollback_temp" ] || rm -f -- "$local_rollback_temp"
                fi
            elif ! rm -f -- "$local_target_file" 2>> "$local_error_file"; then
                local_rollback_failed=1
            fi
            local_rollback_index=$((local_rollback_index - 1))
        done

        if [ "$local_rollback_failed" -ne 0 ]; then
            printf 'error: rendered target publication failed and rollback was incomplete\n' >&2
        else
            printf 'error: rendered target publication failed; prior targets were restored\n' >&2
        fi
        return 4
    done

    if [ -n "$local_callback" ]; then
        "$local_callback" "$local_context" "$local_selection_file" "$local_artifact" "$local_output_resolved" \
            "$local_profile" "$local_modules_input" "$local_additional" "$local_platform"
    fi
)
