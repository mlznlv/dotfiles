# Source-only resolve, prerequisite, plan, and apply command adapters.

resolve_command() {
    parse_consuming_selection_options resolve 0 "$@"
    [ "$DOTFILES_SELECTION_HELP" -eq 0 ] || return 0
    if [ -z "$DOTFILES_SELECTION_PLATFORM" ]; then
        DOTFILES_SELECTION_PLATFORM=$(detect_platform) || exit $?
    fi
    validate_platform "$DOTFILES_SELECTION_PLATFORM" || exit $?
    dotfiles_effective_selection "$DOTFILES_SELECTION_EXPLICIT_BASE" \
        "$DOTFILES_SELECTION_PROFILE" "$DOTFILES_SELECTION_MODULES" \
        "$DOTFILES_SELECTION_ADDITIONAL" "$DOTFILES_SELECTION_PLATFORM" || return $?
    run_catalog resolve "$DOTFILES_SELECTION_PLATFORM" 0 "" \
        "$DOTFILES_EFFECTIVE_PROFILE" "$DOTFILES_EFFECTIVE_MODULES" \
        "$DOTFILES_EFFECTIVE_ADDITIONAL"
}
prerequisite_check_command() {
    parse_consuming_selection_options "prerequisite check" 0 "$@"
    [ "$DOTFILES_SELECTION_HELP" -eq 0 ] || return 0
    if [ -z "$DOTFILES_SELECTION_PLATFORM" ]; then
        DOTFILES_SELECTION_PLATFORM=$(detect_platform) || exit $?
    fi
    validate_platform "$DOTFILES_SELECTION_PLATFORM" || exit $?
    if [ ! -f "$PREREQUISITE_PROGRAM" ]; then
        printf 'error: prerequisite checker implementation is missing\n' >&2
        return 4
    fi

    dotfiles_effective_selection "$DOTFILES_SELECTION_EXPLICIT_BASE" \
        "$DOTFILES_SELECTION_PROFILE" "$DOTFILES_SELECTION_MODULES" \
        "$DOTFILES_SELECTION_ADDITIONAL" "$DOTFILES_SELECTION_PLATFORM" || return $?

    prerequisite_records=$(run_catalog prerequisites "$DOTFILES_SELECTION_PLATFORM" 0 "" \
        "$DOTFILES_EFFECTIVE_PROFILE" "$DOTFILES_EFFECTIVE_MODULES" \
        "$DOTFILES_EFFECTIVE_ADDITIONAL") || return $?
    # shellcheck source=../lib/prerequisite-check.sh
    source "$PREREQUISITE_PROGRAM"
    prerequisite_check_records "$prerequisite_records"
}

configuration_command() {
    local command_kind=$1
    shift
    local allow_yes=0

    [ "$command_kind" != apply ] || allow_yes=1
    parse_consuming_selection_options "$command_kind" "$allow_yes" "$@"
    [ "$DOTFILES_SELECTION_HELP" -eq 0 ] || return 0
    if [ -z "$DOTFILES_SELECTION_PLATFORM" ]; then
        DOTFILES_SELECTION_PLATFORM=$(detect_platform) || exit $?
    fi
    if ! validate_platform "$DOTFILES_SELECTION_PLATFORM" >/dev/null 2>&1; then
        if [ "$command_kind" = plan ]; then
            printf 'error: unsupported planning platform\n' >&2
        else
            printf 'error: unsupported apply platform\n' >&2
        fi
        return 3
    fi
    if [ ! -f "$PLAN_PROGRAM" ] || [ ! -f "$RENDER_PROGRAM" ] || [ ! -f "$PREREQUISITE_PROGRAM" ]; then
        printf 'error: configuration planner implementation is missing\n' >&2
        return 4
    fi

    # shellcheck source=../lib/render.sh
    source "$RENDER_PROGRAM"
    # shellcheck source=../lib/plan.sh
    source "$PLAN_PROGRAM"
    if [ "$command_kind" = plan ]; then
        dotfiles_effective_selection "$DOTFILES_SELECTION_EXPLICIT_BASE" \
            "$DOTFILES_SELECTION_PROFILE" "$DOTFILES_SELECTION_MODULES" \
            "$DOTFILES_SELECTION_ADDITIONAL" "$DOTFILES_SELECTION_PLATFORM" || return $?
        dotfiles_plan_selection "$DOTFILES_EFFECTIVE_PROFILE" "$DOTFILES_EFFECTIVE_MODULES" \
            "$DOTFILES_EFFECTIVE_ADDITIONAL" "$DOTFILES_SELECTION_PLATFORM"
        return $?
    fi
    if [ ! -f "$APPLY_PROGRAM" ]; then
        printf 'error: configuration apply implementation is missing\n' >&2
        return 4
    fi
    # shellcheck source=../lib/apply.sh
    source "$APPLY_PROGRAM"
    dotfiles_apply_selection "$DOTFILES_SELECTION_EXPLICIT_BASE" \
        "$DOTFILES_SELECTION_PROFILE" "$DOTFILES_SELECTION_MODULES" \
        "$DOTFILES_SELECTION_ADDITIONAL" "$DOTFILES_SELECTION_PLATFORM" \
        "$DOTFILES_SELECTION_YES"
}

plan_command() {
    configuration_command plan "$@"
}

apply_command() {
    configuration_command apply "$@"
}
