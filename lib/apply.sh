#!/usr/bin/env bash

# Confirmed, fresh selected-target application through chezmoi.

dotfiles_apply_cleanup() {
    [ -z "${DOTFILES_APPLY_PRIVATE:-}" ] || rm -rf -- "$DOTFILES_APPLY_PRIVATE"
}

dotfiles_apply_record_count() {
    local local_record_file=$1
    local local_module local_action local_source local_target local_extra
    local local_count=0

    [ -f "$local_record_file" ] && [ ! -L "$local_record_file" ] || return 3
    while IFS=$'\t' read -r local_module local_action local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        [ -z "$local_extra" ] || return 3
        local_count=$((local_count + 1))
    done < "$local_record_file"
    printf '%s\n' "$local_count"
}

dotfiles_apply_snapshot_bases() {
    if [ "$#" -ne 2 ]; then
        return 3
    fi

    local local_records=$1
    local local_snapshot_directory=$2
    local local_allowed=0
    local local_index=0
    local local_module local_action local_source local_target local_extra
    local local_destination

    if [ -n "${DOTFILES_APPLY_PRIVATE:-}" ]; then
        case "$local_snapshot_directory" in
            "$DOTFILES_APPLY_PRIVATE"/*) local_allowed=1 ;;
        esac
    fi
    if [ -n "${DOTFILES_PLAN_PRIVATE:-}" ]; then
        case "$local_snapshot_directory" in
            "$DOTFILES_PLAN_PRIVATE"/*) local_allowed=1 ;;
        esac
    fi
    [ "$local_allowed" -eq 1 ] || return 3
    [ -f "$local_records" ] && [ ! -L "$local_records" ] || return 3
    mkdir "$local_snapshot_directory" || return 4

    while IFS=$'\t' read -r local_module local_action local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        local_index=$((local_index + 1))
        if [ -n "$local_extra" ] || [ -z "$local_source" ] ||
           ! dotfiles_plan_target_safe "$DOTFILES_PLAN_HOME" "$local_target"; then
            return 3
        fi
        local_destination="${DOTFILES_PLAN_HOME}/${local_target}"
        case "$local_action" in
            create)
                [ ! -e "$local_destination" ] && [ ! -L "$local_destination" ] || return 3
                ;;
            update)
                [ -f "$local_destination" ] && [ ! -L "$local_destination" ] || return 3
                cp -- "$local_destination" "${local_snapshot_directory}/${local_index}" || return 4
                chmod 600 "${local_snapshot_directory}/${local_index}" || return 4
                cmp -s "${local_snapshot_directory}/${local_index}" "$local_destination" || return 3
                ;;
            *) return 3 ;;
        esac
    done < "$local_records"
}

dotfiles_apply_bases_match() {
    if [ "$#" -ne 3 ]; then
        return 3
    fi

    local local_records=$1
    local local_displayed_bases=$2
    local local_fresh_bases=$3
    local local_index=0
    local local_module local_action local_source local_target local_extra

    [ -d "$local_displayed_bases" ] && [ ! -L "$local_displayed_bases" ] || return 3
    [ -d "$local_fresh_bases" ] && [ ! -L "$local_fresh_bases" ] || return 3
    while IFS=$'\t' read -r local_module local_action local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        local_index=$((local_index + 1))
        case "$local_action" in
            create)
                [ ! -e "${local_displayed_bases}/${local_index}" ] &&
                    [ ! -e "${local_fresh_bases}/${local_index}" ] || return 3
                ;;
            update)
                cmp -s "${local_displayed_bases}/${local_index}" \
                    "${local_fresh_bases}/${local_index}" || return 3
                ;;
            *) return 3 ;;
        esac
    done < "$local_records"
}

dotfiles_apply_capture_displayed() {
    if [ "$#" -ne 9 ]; then
        return 3
    fi

    local local_context=$1
    local local_selection_file=$2
    local local_artifact=$3
    local local_render_output=$4
    local local_records=$9
    local local_module local_source local_target local_extra
    local local_snapshot_target

    case "${DOTFILES_APPLY_DISPLAYED:-}" in
        "${DOTFILES_APPLY_PRIVATE:-}"/*) ;;
        *) return 3 ;;
    esac
    [ -d "$DOTFILES_APPLY_DISPLAYED" ] && [ ! -L "$DOTFILES_APPLY_DISPLAYED" ] || return 3
    mkdir "${DOTFILES_APPLY_DISPLAYED}/rendered" || return 4
    cp -- "$local_context" "${DOTFILES_APPLY_DISPLAYED}/context.toml" || return 4
    cp -- "$local_selection_file" "${DOTFILES_APPLY_DISPLAYED}/selection.tsv" || return 4
    cp -- "$local_records" "${DOTFILES_APPLY_DISPLAYED}/records.tsv" || return 4
    printf '%s' "$local_artifact" > "${DOTFILES_APPLY_DISPLAYED}/artifact" || return 4

    while IFS=$'\t' read -r local_module local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        if [ -n "$local_extra" ] || [ -z "$local_source" ] || [ -z "$local_target" ]; then
            return 3
        fi
        local_snapshot_target="${DOTFILES_APPLY_DISPLAYED}/rendered/${local_target}"
        mkdir -p "$(dirname -- "$local_snapshot_target")" || return 4
        cp -- "${local_render_output}/${local_target}" "$local_snapshot_target" || return 4
    done < "$local_selection_file"

    chmod 600 "${DOTFILES_APPLY_DISPLAYED}/context.toml" \
        "${DOTFILES_APPLY_DISPLAYED}/selection.tsv" \
        "${DOTFILES_APPLY_DISPLAYED}/records.tsv" \
        "${DOTFILES_APPLY_DISPLAYED}/artifact" || return 4
    dotfiles_apply_snapshot_bases "$local_records" \
        "${DOTFILES_APPLY_DISPLAYED}/destination-bases"
}

dotfiles_apply_authority_matches() {
    if [ "$#" -ne 6 ]; then
        return 3
    fi

    local local_context=$1
    local local_selection_file=$2
    local local_artifact=$3
    local local_render_output=$4
    local local_records=$5
    local local_fresh_bases=$6
    local local_displayed_artifact
    local local_module local_source local_target local_extra

    cmp -s "${DOTFILES_APPLY_DISPLAYED}/context.toml" "$local_context" || return 3
    cmp -s "${DOTFILES_APPLY_DISPLAYED}/selection.tsv" "$local_selection_file" || return 3
    cmp -s "${DOTFILES_APPLY_DISPLAYED}/records.tsv" "$local_records" || return 3
    dotfiles_apply_bases_match "$local_records" \
        "${DOTFILES_APPLY_DISPLAYED}/destination-bases" "$local_fresh_bases" || return 3
    local_displayed_artifact=$(<"${DOTFILES_APPLY_DISPLAYED}/artifact")
    [ "$local_displayed_artifact" = "$local_artifact" ] || return 3

    while IFS=$'\t' read -r local_module local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        if [ -n "$local_extra" ] || [ -z "$local_source" ] || [ -z "$local_target" ]; then
            return 3
        fi
        cmp -s "${DOTFILES_APPLY_DISPLAYED}/rendered/${local_target}" \
            "${local_render_output}/${local_target}" || return 3
    done < "$local_selection_file"
}

dotfiles_apply_report_failure() {
    local local_records=$1
    local local_failed_index=$2
    local local_total
    local local_completed
    local local_unattempted
    local local_index=0
    local local_module local_action local_source local_target local_extra
    local local_state

    local_total=$(dotfiles_apply_record_count "$local_records") || return 3
    [ "$local_failed_index" -ge 1 ] && [ "$local_failed_index" -le "$local_total" ] || return 3
    local_completed=$((local_failed_index - 1))
    local_unattempted=$((local_total - local_failed_index))
    printf 'Apply failed: %s completed, 1 failed, %s unattempted\n' "$local_completed" "$local_unattempted"

    while IFS=$'\t' read -r local_module local_action local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        local_index=$((local_index + 1))
        if [ "$local_index" -lt "$local_failed_index" ]; then
            local_state=completed
        elif [ "$local_index" -eq "$local_failed_index" ]; then
            local_state=failed
        else
            local_state=unattempted
        fi
        printf '%s: %s chezmoi:target:%s\n' "$local_state" "$local_module" "$local_target"
    done < "$local_records"
}

dotfiles_apply_handle_signal() {
    local local_status=$1
    if [ "${DOTFILES_APPLY_MUTATION_STARTED:-0}" -eq 1 ] &&
       [ -n "${DOTFILES_APPLY_ACTIVE_RECORDS:-}" ] &&
       [ "${DOTFILES_APPLY_CURRENT_INDEX:-0}" -gt 0 ]; then
        dotfiles_apply_report_failure "$DOTFILES_APPLY_ACTIVE_RECORDS" "$DOTFILES_APPLY_CURRENT_INDEX" || true
    else
        printf 'error: configuration apply was interrupted before mutation\n' >&2
    fi
    return "$local_status"
}

dotfiles_apply_recheck_artifact() (
    if [ "$#" -ne 5 ]; then
        return 3
    fi

    local local_profile=$1
    local local_modules=$2
    local local_additional=$3
    local local_platform=$4
    local local_expected_artifact=$5
    local local_prerequisite_records
    local local_module local_locator local_candidate local_extra
    local local_count=0

    [ -n "$local_expected_artifact" ] || return 3
    local_prerequisite_records=$(run_catalog prerequisites "$local_platform" 0 "" \
        "$local_profile" "$local_modules" "$local_additional") || return $?
    prerequisite_check_records "$local_prerequisite_records" \
        > "$DOTFILES_APPLY_RECHECK_LOG" 2> "$DOTFILES_APPLY_ERROR_LOG" || return $?

    while IFS=$'\t' read -r local_module local_locator local_candidate local_extra; do
        [ -n "$local_module" ] || continue
        if [ -n "$local_extra" ] ||
           [ "$local_module" != shell.zsh.autosuggestions ] ||
           [ "$local_locator" != share:zsh-autosuggestions/zsh-autosuggestions.zsh ] ||
           [ "$local_candidate" != "$local_expected_artifact" ]; then
            return 3
        fi
        local_count=$((local_count + 1))
    done <<< "${PREREQUISITE_ARTIFACT_FACTS:-}"
    [ "$local_count" -eq 1 ]
)

dotfiles_apply_fail_target() {
    local local_records=$1
    local local_index=$2
    local local_preapply_status=$3

    if [ "${DOTFILES_APPLY_MUTATION_STARTED:-0}" -eq 1 ]; then
        dotfiles_apply_report_failure "$local_records" "$local_index" || return 6
        return 6
    fi
    return "$local_preapply_status"
}

dotfiles_apply_recompute_and_apply() {
    if [ "$#" -ne 9 ]; then
        return 3
    fi

    local local_context=$1
    local local_selection_file=$2
    local local_artifact=$3
    local local_render_output=$4
    local local_profile=$5
    local local_modules=$6
    local local_additional=$7
    local local_platform=$8
    local local_plan_records=$9
    local local_apply_chezmoi=${DOTFILES_APPLY_CHEZMOI_BIN:-$CHEZMOI_BIN}
    local local_total
    local local_index=0
    local local_module local_action local_source local_target local_extra
    local local_destination
    local local_rendered_target
    local local_base_snapshot="${DOTFILES_PLAN_PRIVATE}/destination-bases"

    dotfiles_apply_snapshot_bases "$local_plan_records" "$local_base_snapshot" || return $?
    dotfiles_apply_authority_matches "$local_context" "$local_selection_file" \
        "$local_artifact" "$local_render_output" "$local_plan_records" \
        "$local_base_snapshot" || return 3
    command -v "$local_apply_chezmoi" >/dev/null 2>&1 || return 4
    local_total=$(dotfiles_apply_record_count "$local_plan_records") || return $?
    [ "$local_total" -gt 0 ] || return 3

    DOTFILES_APPLY_ACTIVE_RECORDS=$local_plan_records
    DOTFILES_APPLY_CURRENT_INDEX=0
    DOTFILES_APPLY_MUTATION_STARTED=0
    DOTFILES_PLAN_SIGNAL_HANDLER=dotfiles_apply_handle_signal
    DOTFILES_APPLY_CACHE="${DOTFILES_PLAN_PRIVATE}/apply-cache"
    DOTFILES_APPLY_STATE="${DOTFILES_PLAN_PRIVATE}/apply-state.boltdb"
    DOTFILES_APPLY_OUTPUT_LOG="${DOTFILES_PLAN_PRIVATE}/apply-output.log"
    DOTFILES_APPLY_ERROR_LOG="${DOTFILES_PLAN_PRIVATE}/apply-error.log"
    DOTFILES_APPLY_RECHECK_LOG="${DOTFILES_PLAN_PRIVATE}/apply-recheck.log"
    mkdir "$DOTFILES_APPLY_CACHE" || return 4
    : > "$DOTFILES_APPLY_OUTPUT_LOG" || return 4
    : > "$DOTFILES_APPLY_ERROR_LOG" || return 4
    : > "$DOTFILES_APPLY_RECHECK_LOG" || return 4

    while IFS=$'\t' read -r local_module local_action local_source local_target local_extra; do
        [ -n "$local_module" ] || continue
        local_index=$((local_index + 1))
        DOTFILES_APPLY_CURRENT_INDEX=$local_index
        local_destination="${DOTFILES_PLAN_HOME}/${local_target}"
        local_rendered_target="${local_render_output}/${local_target}"

        if [ "$local_target" = .zshrc ] && [ -n "$local_artifact" ]; then
            dotfiles_apply_recheck_artifact "$local_profile" "$local_modules" "$local_additional" \
                "$local_platform" "$local_artifact" || {
                local local_recheck_status=$?
                dotfiles_apply_fail_target "$local_plan_records" "$local_index" "$local_recheck_status"
                return $?
            }
        fi

        dotfiles_plan_target_safe "$DOTFILES_PLAN_HOME" "$local_target" || {
            dotfiles_apply_fail_target "$local_plan_records" "$local_index" 3
            return $?
        }
        case "$local_action" in
            create) [ ! -e "$local_destination" ] && [ ! -L "$local_destination" ] || {
                dotfiles_apply_fail_target "$local_plan_records" "$local_index" 3
                return $?
            } ;;
            update)
                if [ ! -f "$local_destination" ] || [ -L "$local_destination" ] ||
                   ! cmp -s "${local_base_snapshot}/${local_index}" "$local_destination"; then
                    dotfiles_apply_fail_target "$local_plan_records" "$local_index" 3
                    return $?
                fi
                ;;
            *) return 3 ;;
        esac

        DOTFILES_APPLY_MUTATION_STARTED=1
        : > "$DOTFILES_APPLY_OUTPUT_LOG" || return 6
        : > "$DOTFILES_APPLY_ERROR_LOG" || return 6
        if "$local_apply_chezmoi" --no-pager --no-tty --config /dev/null --config-format toml \
            --color=false --progress=false --use-builtin-diff --use-builtin-age=true \
            --use-builtin-git=true --refresh-externals=never --interactive=false --mode=file \
            --source "${SOURCE_DIR}/home" --destination "$DOTFILES_PLAN_HOME" \
            --cache "$DOTFILES_APPLY_CACHE" --persistent-state "$DOTFILES_APPLY_STATE" \
            --override-data-file "$local_context" --force apply --include=dirs,files \
            --exclude=encrypted,externals,scripts,symlinks --recursive=false --parent-dirs \
            "$local_destination" > "$DOTFILES_APPLY_OUTPUT_LOG" 2> "$DOTFILES_APPLY_ERROR_LOG"; then
            :
        else
            dotfiles_apply_report_failure "$local_plan_records" "$local_index" || true
            return 6
        fi

        if ! dotfiles_plan_target_safe "$DOTFILES_PLAN_HOME" "$local_target" ||
           [ ! -f "$local_destination" ] || [ -L "$local_destination" ] ||
           ! cmp -s "$local_rendered_target" "$local_destination"; then
            dotfiles_apply_report_failure "$local_plan_records" "$local_index" || true
            return 6
        fi
    done < "$local_plan_records"

    printf 'Apply complete: %s completed, 0 failed, 0 unattempted\n' "$local_total"
}

dotfiles_apply_selection() {
    if [ "$#" -ne 5 ]; then
        printf 'error: internal apply requires profile, modules, additions, platform, and confirmation mode\n' >&2
        return 2
    fi

    local local_profile=$1
    local local_modules=$2
    local local_additional=$3
    local local_platform=$4
    local local_yes=$5
    local local_temp_parent=${TMPDIR:-/tmp}
    local local_status
    local local_answer=

    case "$local_yes" in 0|1) ;; *) return 2 ;; esac
    case "$local_temp_parent" in /*) ;; *) local_temp_parent=/tmp ;; esac
    umask 077
    if ! DOTFILES_APPLY_PRIVATE=$(mktemp -d "${local_temp_parent%/}/dotfiles-apply.XXXXXX"); then
        printf 'error: private apply directory could not be created\n' >&2
        return 4
    fi
    DOTFILES_APPLY_DISPLAYED="${DOTFILES_APPLY_PRIVATE}/displayed"
    DOTFILES_APPLY_MUTATION_STARTED=0
    DOTFILES_APPLY_ACTIVE_RECORDS=
    DOTFILES_APPLY_CURRENT_INDEX=0
    DOTFILES_PLAN_SIGNAL_HANDLER=dotfiles_apply_handle_signal
    DOTFILES_PLAN_RERUN_COMMAND=apply
    trap dotfiles_apply_cleanup EXIT
    trap 'dotfiles_apply_handle_signal 129; exit 129' HUP
    trap 'dotfiles_apply_handle_signal 130; exit 130' INT
    trap 'dotfiles_apply_handle_signal 143; exit 143' TERM
    chmod 700 "$DOTFILES_APPLY_PRIVATE" || return 4
    mkdir "$DOTFILES_APPLY_DISPLAYED" || return 4

    if dotfiles_plan_selection_then dotfiles_apply_capture_displayed \
        "$local_profile" "$local_modules" "$local_additional" "$local_platform"; then
        :
    else
        local_status=$?
        case "$local_status" in
            3) printf 'error: selected configuration could not be planned safely; no changes were applied\n' >&2 ;;
            4) printf 'error: configuration apply foundation is unavailable; no changes were applied\n' >&2 ;;
            5) printf 'error: selected prerequisites or comparison failed; no changes were applied\n' >&2 ;;
        esac
        return "$local_status"
    fi

    if [ ! -s "${DOTFILES_APPLY_DISPLAYED}/records.tsv" ]; then
        dotfiles_plan_format_records "${DOTFILES_APPLY_DISPLAYED}/records.tsv" "$local_platform"
        return $?
    fi
    dotfiles_plan_format_records "${DOTFILES_APPLY_DISPLAYED}/records.tsv" "$local_platform" || return $?
    printf '\nSoftware installation: none\n'

    if [ "$local_yes" -eq 0 ]; then
        if [ ! -t 0 ]; then
            printf 'error: non-interactive apply requires --yes; no changes were applied\n' >&2
            return 2
        fi
        printf '\nApply this configuration? Type yes to continue:\n'
        if ! IFS= read -r local_answer || [ "$local_answer" != yes ]; then
            printf 'Cancelled. No changes were applied.\n'
            return 0
        fi
    fi

    if dotfiles_plan_selection_then dotfiles_apply_recompute_and_apply \
        "$local_profile" "$local_modules" "$local_additional" "$local_platform"; then
        return 0
    else
        local_status=$?
    fi
    case "$local_status" in
        3) printf 'error: configuration changed or became unsafe after confirmation; rerun dotfiles apply\n' >&2 ;;
        4) printf 'error: configuration apply foundation became unavailable after confirmation\n' >&2 ;;
        5) printf 'error: selected prerequisites, artifact, render, or comparison changed after confirmation; rerun dotfiles apply\n' >&2 ;;
        6|129|130|143) ;;
        *) printf 'error: configuration apply failed before mutation\n' >&2 ;;
    esac
    return "$local_status"
}
