#!/usr/bin/env bash

# Deterministic read-only configuration planning over selected chezmoi targets.

dotfiles_plan_cleanup() {
    [ -z "${DOTFILES_PLAN_PRIVATE:-}" ] || rm -rf -- "$DOTFILES_PLAN_PRIVATE"
}

dotfiles_plan_valid_home() {
    local local_home=$1
    case "$local_home" in /*) ;; *) return 1 ;; esac
    case "$local_home" in /|*/|*'//'*) return 1 ;; esac
    case "/${local_home#/}/" in *'/./'*|*'/../'*) return 1 ;; esac
    dotfiles_render_scalar_safe "$local_home"
}

dotfiles_plan_target_safe() {
    local local_home=$1
    local local_target=$2
    local local_current=$local_home
    local local_remaining=$local_target
    local local_segment

    case "$local_target" in ""|/*|*'//'*) return 1 ;; esac
    case "/${local_target}/" in *'/./'*|*'/../'*) return 1 ;; esac
    dotfiles_render_scalar_safe "$local_target" || return 1

    while case "$local_remaining" in */*) true ;; *) false ;; esac; do
        local_segment=${local_remaining%%/*}
        local_remaining=${local_remaining#*/}
        local_current="${local_current}/${local_segment}"
        [ ! -L "$local_current" ] || return 1
        if [ -e "$local_current" ]; then
            [ -d "$local_current" ] || return 1
        else
            return 0
        fi
    done

    local_current="${local_current}/${local_remaining}"
    [ ! -L "$local_current" ] || return 1
    [ ! -e "$local_current" ] || [ -f "$local_current" ]
}

dotfiles_plan_has_mapping() {
    local local_wanted=$1
    shift
    local local_value
    for local_value in "$@"; do
        [ "$local_value" = "$local_wanted" ] && return 0
    done
    return 1
}

dotfiles_plan_compare_selection() {
    if [ "$#" -ne 8 ]; then
        return 3
    fi

    local local_context=$1
    local local_selection_file=$2
    local local_rendered_artifact=$3
    local local_render_output=$4
    local local_profile=$5
    local local_modules=$6
    local local_additional=$7
    local local_platform=$8
    local local_module local_source local_target local_extra
    local local_previous_target=
    local local_prerequisite_records
    local local_status
    local local_fact_module local_fact_locator local_fact_path
    local local_fact_count=0
    local local_plan_chezmoi=${DOTFILES_PLAN_CHEZMOI_BIN:-$CHEZMOI_BIN}
    local local_status_line local_first local_effect local_separator local_result_target
    local local_mapping_index local_action local_expected_effect
    local local_seen_results=
    local local_target_file
    local local_index
    local LC_ALL=C
    local -a local_modules_by_target=()
    local -a local_sources=()
    local -a local_targets=()
    local -a local_destination_targets=()
    local -a local_target_existed=()

    [ -f "$local_context" ] && [ ! -L "$local_context" ] || return 3
    [ -f "$local_selection_file" ] && [ ! -L "$local_selection_file" ] || return 3
    [ -d "$local_render_output" ] && [ ! -L "$local_render_output" ] || return 3
    command -v "$local_plan_chezmoi" >/dev/null 2>&1 || return 4

    while IFS=$'\t' read -r local_module local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        if [ -z "$local_source" ] || [ -z "$local_target" ] || [ -n "$local_extra" ] ||
           ! printf '%s' "$local_module" | grep -Eq '^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$' ||
           ! dotfiles_render_scalar_safe "$local_source" ||
           ! dotfiles_plan_target_safe "$DOTFILES_PLAN_HOME" "$local_target"; then
            return 3
        fi
        if [ -n "$local_previous_target" ] && [[ "$local_target" < "$local_previous_target" || "$local_target" = "$local_previous_target" ]]; then
            return 3
        fi
        local_target_file="${local_render_output}/${local_target}"
        [ -f "$local_target_file" ] && [ ! -L "$local_target_file" ] || return 3
        local_modules_by_target[${#local_modules_by_target[@]}]=$local_module
        local_sources[${#local_sources[@]}]=$local_source
        local_targets[${#local_targets[@]}]=$local_target
        local_destination_targets[${#local_destination_targets[@]}]="${DOTFILES_PLAN_HOME}/${local_target}"
        if [ -e "${DOTFILES_PLAN_HOME}/${local_target}" ]; then
            local_target_existed[${#local_target_existed[@]}]=1
        else
            local_target_existed[${#local_target_existed[@]}]=0
        fi
        local_previous_target=$local_target
    done < "$local_selection_file"

    [ -s "$local_selection_file" ] || return 3

    if [ -n "$local_rendered_artifact" ]; then
        if ! declare -F prerequisite_check_records >/dev/null 2>&1; then
            source "$PREREQUISITE_PROGRAM"
        fi
        local_prerequisite_records=$(run_catalog prerequisites "$local_platform" 0 "" "$local_profile" "$local_modules" "$local_additional") || return $?
        if prerequisite_check_records "$local_prerequisite_records" > "$DOTFILES_PLAN_RECHECK_LOG" 2> "$DOTFILES_PLAN_ERROR_LOG"; then
            :
        else
            return $?
        fi
        while IFS=$'\t' read -r local_fact_module local_fact_locator local_fact_path local_extra; do
            [ -n "$local_fact_module" ] || continue
            if [ -n "$local_extra" ] || [ "$local_fact_module" != shell.zsh.autosuggestions ] ||
               [ "$local_fact_locator" != share:zsh-autosuggestions/zsh-autosuggestions.zsh ] ||
               ! dotfiles_render_scalar_safe "$local_fact_path"; then
                return 3
            fi
            local_fact_count=$((local_fact_count + 1))
            [ "$local_fact_path" = "$local_rendered_artifact" ] || return 3
        done <<< "${PREREQUISITE_ARTIFACT_FACTS:-}"
        [ "$local_fact_count" -eq 1 ] || return 3
    fi

    for local_index in "${!local_targets[@]}"; do
        local_target=${local_targets[$local_index]}
        dotfiles_plan_target_safe "$DOTFILES_PLAN_HOME" "$local_target" || return 3
        if [ "${local_target_existed[$local_index]}" -eq 1 ]; then
            [ -e "${DOTFILES_PLAN_HOME}/${local_target}" ] || return 3
        else
            [ ! -e "${DOTFILES_PLAN_HOME}/${local_target}" ] || return 3
        fi
    done

    if "$local_plan_chezmoi" --no-pager --no-tty --dry-run --config /dev/null --config-format toml \
        --color=false --progress=false --use-builtin-diff --refresh-externals=never --skip-secrets \
        --source "${SOURCE_DIR}/home" --destination "$DOTFILES_PLAN_HOME" \
        --cache "$DOTFILES_PLAN_CACHE" --persistent-state "$DOTFILES_PLAN_STATE" \
        --override-data-file "$local_context" status --path-style relative --recursive=false \
        "${local_destination_targets[@]}" > "$DOTFILES_PLAN_STATUS_LOG" 2> "$DOTFILES_PLAN_ERROR_LOG"; then
        :
    else
        return 5
    fi

    local_previous_target=
    while IFS= read -r local_status_line; do
        [ -n "$local_status_line" ] || continue
        [ "${#local_status_line}" -ge 4 ] || return 3
        local_first=${local_status_line:0:1}
        local_effect=${local_status_line:1:1}
        local_separator=${local_status_line:2:1}
        local_result_target=${local_status_line:3}
        case "$local_first" in ' '|A|D|M) ;; *) return 3 ;; esac
        case "$local_effect" in A|M) ;; *) return 3 ;; esac
        [ "$local_separator" = ' ' ] || return 3
        dotfiles_render_scalar_safe "$local_result_target" || return 3

        local_mapping_index=-1
        for local_index in "${!local_targets[@]}"; do
            if [ "${local_targets[$local_index]}" = "$local_result_target" ]; then
                local_mapping_index=$local_index
                break
            fi
        done
        [ "$local_mapping_index" -ge 0 ] || return 3
        case "$local_seen_results" in
            "$local_result_target"|"$local_result_target"$'\n'*|*$'\n'"$local_result_target"|*$'\n'"$local_result_target"$'\n'*) return 3 ;;
        esac
        if [ -n "$local_previous_target" ] && [[ "$local_result_target" < "$local_previous_target" || "$local_result_target" = "$local_previous_target" ]]; then
            return 3
        fi
        local_previous_target=$local_result_target
        local_seen_results="${local_seen_results}${local_seen_results:+
}${local_result_target}"

        if [ "${local_target_existed[$local_mapping_index]}" -eq 1 ]; then
            local_action=update
            local_expected_effect=M
        else
            local_action=create
            local_expected_effect=A
        fi
        [ "$local_effect" = "$local_expected_effect" ] || return 3
        printf '%s\t%s\t%s\t%s\n' "${local_modules_by_target[$local_mapping_index]}" "$local_action" \
            "${local_sources[$local_mapping_index]}" "$local_result_target" >> "$DOTFILES_PLAN_RECORDS"
    done < "$DOTFILES_PLAN_STATUS_LOG"

    for local_index in "${!local_targets[@]}"; do
        local_target=${local_targets[$local_index]}
        dotfiles_plan_target_safe "$DOTFILES_PLAN_HOME" "$local_target" || return 3
        if [ "${local_target_existed[$local_index]}" -eq 1 ]; then
            [ -e "${DOTFILES_PLAN_HOME}/${local_target}" ] || return 3
        else
            [ ! -e "${DOTFILES_PLAN_HOME}/${local_target}" ] || return 3
        fi
    done

    return 0
}

dotfiles_plan_selection() (
    if [ "$#" -ne 4 ]; then
        printf 'error: internal planner requires profile, modules, additions, and platform\n' >&2
        return 2
    fi

    local local_profile=$1
    local local_modules=$2
    local local_additional=$3
    local local_platform=$4
    local local_home=${HOME:-}
    local local_home_resolved
    local local_temp_parent=${TMPDIR:-/tmp}
    local local_private
    local local_render_output
    local local_prerequisite_records
    local local_status
    local local_module local_kind local_identifier local_extra
    local local_count=0
    local local_index=0
    local local_action local_source local_target
    local local_records=

    if [ -n "$local_profile" ] && [ -n "$local_modules" ]; then
        return 2
    fi
    if [ -z "$local_profile" ] && [ -z "$local_modules" ]; then
        return 2
    fi
    validate_platform "$local_platform" >/dev/null 2>&1 || return $?
    if ! dotfiles_plan_valid_home "$local_home" || [ ! -d "$local_home" ] || [ -L "$local_home" ]; then
        printf 'error: HOME must be a literal absolute directory for planning\n' >&2
        return 3
    fi
    if ! local_home_resolved=$(CDPATH= cd -- "$local_home" 2>/dev/null && pwd -P) || [ "$local_home_resolved" != "$local_home" ]; then
        printf 'error: HOME must resolve to its literal absolute directory for planning\n' >&2
        return 3
    fi

    case "$local_temp_parent" in /*) ;; *) local_temp_parent=/tmp ;; esac
    umask 077
    if ! local_private=$(mktemp -d "${local_temp_parent%/}/dotfiles-plan.XXXXXX"); then
        printf 'error: private planning directory could not be created\n' >&2
        return 4
    fi
    DOTFILES_PLAN_PRIVATE=$local_private
    trap dotfiles_plan_cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    chmod 700 "$local_private" || return 4

    DOTFILES_PLAN_HOME=$local_home_resolved
    DOTFILES_PLAN_CACHE="${local_private}/cache"
    DOTFILES_PLAN_STATE="${local_private}/state.boltdb"
    DOTFILES_PLAN_STATUS_LOG="${local_private}/status.log"
    DOTFILES_PLAN_ERROR_LOG="${local_private}/error.log"
    DOTFILES_PLAN_RECHECK_LOG="${local_private}/recheck.log"
    DOTFILES_PLAN_RECORDS="${local_private}/records.tsv"
    local_render_output="${local_private}/rendered"
    mkdir "$DOTFILES_PLAN_CACHE" "$local_render_output" || return 4
    : > "$DOTFILES_PLAN_RECORDS" || return 4

    if local_prerequisite_records=$(run_catalog prerequisites "$local_platform" 0 "" "$local_profile" "$local_modules" "$local_additional" 2> "$DOTFILES_PLAN_ERROR_LOG"); then
        :
    else
        local_status=$?
        if [ "$local_status" -eq 4 ]; then
            printf 'error: catalog comparison foundation is unavailable\n' >&2
        else
            printf 'error: invalid catalog or selected composition; no plan was produced\n' >&2
        fi
        return "$local_status"
    fi
    if ! declare -F prerequisite_check_records >/dev/null 2>&1; then
        source "$PREREQUISITE_PROGRAM"
    fi
    if prerequisite_check_records "$local_prerequisite_records" > "${local_private}/prerequisites.log" 2> "$DOTFILES_PLAN_ERROR_LOG"; then
        :
    else
        local_status=$?
        if [ "$local_status" -eq 5 ]; then
            while IFS=$'\t' read -r local_module local_kind local_identifier local_extra; do
                [ -n "$local_module" ] || continue
                [ -z "$local_extra" ] || continue
                printf 'error: module %s requires %s %s on %s\n' "$local_module" "$local_kind" "$local_identifier" "$local_platform" >&2
            done <<< "${PREREQUISITE_MISSING_FACTS:-}"
            printf 'Provide the missing prerequisites outside this project, then run dotfiles plan again.\n' >&2
        elif [ "$local_status" -eq 4 ]; then
            while IFS=$'\t' read -r local_module local_kind local_identifier local_extra; do
                [ "$local_kind" = application ] || continue
                printf 'error: module %s application %s cannot be checked on %s\n' "$local_module" "$local_identifier" "$local_platform" >&2
                break
            done <<< "$local_prerequisite_records"
        else
            printf 'error: selected prerequisite data or local artifact roots are invalid\n' >&2
        fi
        return "$local_status"
    fi

    if dotfiles_render_selection_then dotfiles_plan_compare_selection "$local_render_output" "$local_profile" "$local_modules" "$local_additional" "$local_platform" 2> "${local_private}/render-error.log"; then
        :
    else
        local_status=$?
        case "$local_status" in
            3) printf 'error: unsafe or malformed selected-target comparison; no plan was produced\n' >&2 ;;
            4) printf 'error: configuration renderer or Chezmoi comparison is unavailable\n' >&2 ;;
            5) printf 'error: selected prerequisites changed or comparison failed; no plan was produced\n' >&2 ;;
            129|130|143) printf 'error: configuration planning was interrupted\n' >&2 ;;
            *) printf 'error: configuration planning failed before producing a plan\n' >&2 ;;
        esac
        return "$local_status"
    fi

    local_records=$(<"$DOTFILES_PLAN_RECORDS")
    if [ -z "$local_records" ]; then
        printf 'No changes.\n'
        return 0
    fi

    while IFS=$'\t' read -r local_module local_action local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        if [ -n "$local_extra" ] ||
           ! printf '%s' "$local_module" | grep -Eq '^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$' ||
           ! dotfiles_plan_has_mapping "$local_action" create update ||
           ! dotfiles_render_scalar_safe "$local_source" ||
           ! dotfiles_render_scalar_safe "$local_target"; then
            printf 'error: invalid internal configuration plan record\n' >&2
            return 3
        fi
        local_count=$((local_count + 1))
    done <<< "$local_records"

    printf 'Prerequisites: satisfied\n'
    if [ "$local_count" -eq 1 ]; then
        printf 'Plan: 1 configuration change for %s\n\n' "$local_platform"
    else
        printf 'Plan: %s configuration changes for %s\n\n' "$local_count" "$local_platform"
    fi
    while IFS=$'\t' read -r local_module local_action local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        local_index=$((local_index + 1))
        printf '%s. %s %s chezmoi:target:%s\n' "$local_index" "$local_action" "$local_module" "$local_target"
        printf '   source: %s\n' "$local_source"
        printf '   network: no; privilege: none\n'
        [ "$local_index" -eq "$local_count" ] || printf '\n'
    done <<< "$local_records"
)
