# Source-only local-selection configuration command adapters and presentation.

config_inspect_command() {
    local resolved_modules
    local summary

    parse_consuming_selection_options "config inspect" 0 "$@"
    [ "$DOTFILES_SELECTION_HELP" -eq 0 ] || return 0
    if [ -z "$DOTFILES_SELECTION_PLATFORM" ]; then
        DOTFILES_SELECTION_PLATFORM=$(detect_platform) || return $?
    fi
    validate_platform "$DOTFILES_SELECTION_PLATFORM" || return $?
    dotfiles_effective_selection "$DOTFILES_SELECTION_EXPLICIT_BASE" \
        "$DOTFILES_SELECTION_PROFILE" "$DOTFILES_SELECTION_MODULES" \
        "$DOTFILES_SELECTION_ADDITIONAL" "$DOTFILES_SELECTION_PLATFORM" || return $?
    resolved_modules=$(run_catalog resolve "$DOTFILES_SELECTION_PLATFORM" 0 "" \
        "$DOTFILES_EFFECTIVE_PROFILE" "$DOTFILES_EFFECTIVE_MODULES" \
        "$DOTFILES_EFFECTIVE_ADDITIONAL") || return $?
    [ -n "$resolved_modules" ] || {
        printf 'error: inspected selection resolved to no modules\n' >&2
        return 3
    }

    summary=$(config_print_inspection "$DOTFILES_EFFECTIVE_SOURCE" \
        "$DOTFILES_EFFECTIVE_PROFILE" "$DOTFILES_EFFECTIVE_MODULES" \
        "$DOTFILES_EFFECTIVE_ADDITIONAL" "$DOTFILES_SELECTION_PLATFORM" \
        "$resolved_modules") || return 4
    printf '%s\n' "$summary"
}

config_doctor_command() {
    local platform=
    local platform_seen=0
    local option

    while [ "$#" -gt 0 ]; do
        option=$1
        case "$option" in
            --platform)
                shift
                [ "$#" -gt 0 ] || usage_error "--platform requires a value"
                case "$1" in ""|--*) usage_error "--platform requires a value" ;; esac
                [ "$platform_seen" -eq 0 ] || usage_error "--platform may be specified only once"
                platform_seen=1
                platform=$1
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *) usage_error "unknown config doctor option" ;;
        esac
        shift
    done

    if [ -z "$platform" ]; then
        platform=$(detect_platform) || return $?
    fi
    validate_platform "$platform" || return $?
    config_require_state_program || return $?
    DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT=doctor dotfiles_config_state_load "$platform" || return $?

    printf 'Local selection file: healthy\n'
    printf 'Schema: 1\n'
    printf 'Composition for %s: valid\n' "$platform"
}

config_resolve_selection() {
    local profile=$1
    local modules=$2
    local additional=$3
    local platform=$4

    dotfiles_config_validate_intent "$profile" "$modules" "$additional" || return $?
    DOTFILES_CONFIG_RESOLVED_MODULES=$(run_catalog resolve "$platform" 0 "" "$profile" "$modules" "$additional") || return $?
    [ -n "$DOTFILES_CONFIG_RESOLVED_MODULES" ] || {
        printf 'error: local selection resolved to no modules\n' >&2
        return 3
    }
}

config_print_proposal() {
    local profile=$1
    local modules=$2
    local additional=$3
    local platform=$4
    local resolved_modules=$5
    local resolved_module

    printf 'Proposed local selection:\n'
    if [ -n "$profile" ]; then
        printf 'Base: profile %s\n' "$profile"
    else
        printf 'Base: modules %s\n' "$modules"
    fi
    if [ -n "$additional" ]; then
        printf 'Additional modules: %s\n' "$additional"
    else
        printf 'Additional modules: none\n'
    fi
    printf 'Resolved modules for %s:\n' "$platform"
    while IFS= read -r resolved_module; do
        [ -n "$resolved_module" ] || continue
        printf '  %s\n' "$resolved_module"
    done <<< "$resolved_modules"
}

config_print_inventory_category() {
    local kind=$1
    local platform=$2
    local records=$3
    local identifier
    local ignored
    local printed=0

    printf 'Available %s for %s:\n' "$kind" "$platform"
    while IFS=$'\t' read -r identifier ignored; do
        [ -n "$identifier" ] || continue
        printf '  %s\n' "$identifier"
        printed=1
    done <<< "$records"
    [ "$printed" -eq 1 ] || printf '  none\n'
}

config_set_command() {
    local profile=
    local modules=
    local additional=
    local platform=
    local profile_seen=0
    local modules_seen=0
    local additional_seen=0
    local platform_seen=0
    local option

    while [ "$#" -gt 0 ]; do
        option=$1
        case "$option" in
            --profile|--modules|--add|--platform)
                shift
                [ "$#" -gt 0 ] || usage_error "${option} requires a value"
                case "$1" in ""|--*) usage_error "${option} requires a value" ;; esac
                case "$option" in
                    --profile)
                        [ "$profile_seen" -eq 0 ] || usage_error "--profile may be specified only once"
                        profile_seen=1
                        profile=$1
                        ;;
                    --modules)
                        [ "$modules_seen" -eq 0 ] || usage_error "--modules may be specified only once"
                        modules_seen=1
                        modules=$1
                        ;;
                    --add)
                        [ "$additional_seen" -eq 0 ] || usage_error "--add may be specified only once"
                        additional_seen=1
                        additional=$1
                        ;;
                    --platform)
                        [ "$platform_seen" -eq 0 ] || usage_error "--platform may be specified only once"
                        platform_seen=1
                        platform=$1
                        ;;
                esac
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *) usage_error "unknown config set option" ;;
        esac
        shift
    done

    if [ -n "$profile" ] && [ -n "$modules" ]; then
        usage_error "--profile and --modules are mutually exclusive"
    fi
    if [ -z "$profile" ] && [ -z "$modules" ]; then
        usage_error "config set requires --profile or --modules"
    fi
    if [ -z "$platform" ]; then
        platform=$(detect_platform) || exit $?
    fi
    validate_platform "$platform" || return $?
    config_require_state_program || return $?
    config_resolve_selection "$profile" "$modules" "$additional" "$platform" || return $?
    config_print_proposal "$profile" "$modules" "$additional" "$platform" "$DOTFILES_CONFIG_RESOLVED_MODULES"

    dotfiles_config_state_set "$profile" "$modules" "$additional" "$platform"
}

config_interactive_command() (
    local profile=
    local modules=
    local additional=
    local platform=
    local platform_seen=0
    local option
    local profile_records
    local module_records
    local base_type
    local answer
    local comparison
    local comparison_status

    while [ "$#" -gt 0 ]; do
        option=$1
        case "$option" in
            --platform)
                shift
                [ "$#" -gt 0 ] || usage_error "--platform requires a value"
                case "$1" in ""|--*) usage_error "--platform requires a value" ;; esac
                [ "$platform_seen" -eq 0 ] || usage_error "--platform may be specified only once"
                platform_seen=1
                platform=$1
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *) usage_error "unknown config interactive option" ;;
        esac
        shift
    done

    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if [ ! -t 0 ]; then
        printf 'error: config interactive requires terminal stdin\n' >&2
        printf 'Run dotfiles config interactive from a terminal.\n' >&2
        return 2
    fi
    if [ -z "$platform" ]; then
        platform=$(detect_platform) || return $?
    fi
    validate_platform "$platform" || return $?
    config_require_state_program || return $?

    profile_records=$(run_catalog list_profiles "$platform" 0) || return $?
    module_records=$(run_catalog list_modules "$platform" 0) || return $?
    config_print_inventory_category profiles "$platform" "$profile_records"
    config_print_inventory_category modules "$platform" "$module_records"

    printf 'Base type (profile or modules):\n'
    if ! IFS= read -r base_type; then
        printf 'error: incomplete interactive local selection\n' >&2
        return 2
    fi
    case "$base_type" in
        profile)
            printf 'Profile ID:\n'
            if ! IFS= read -r profile; then
                printf 'error: incomplete interactive local selection\n' >&2
                return 2
            fi
            ;;
        modules)
            printf 'Module IDs (comma-separated):\n'
            if ! IFS= read -r modules; then
                printf 'error: incomplete interactive local selection\n' >&2
                return 2
            fi
            ;;
        *)
            printf 'error: base type must be exactly profile or modules\n' >&2
            return 3
            ;;
    esac

    printf 'Additional module IDs (comma-separated, empty for none):\n'
    if ! IFS= read -r additional; then
        printf 'error: incomplete interactive local selection\n' >&2
        return 2
    fi

    config_resolve_selection "$profile" "$modules" "$additional" "$platform" || return $?
    config_print_proposal "$profile" "$modules" "$additional" "$platform" "$DOTFILES_CONFIG_RESOLVED_MODULES"

    comparison=$(dotfiles_config_state_compare "$profile" "$modules" "$additional" "$platform")
    comparison_status=$?
    [ "$comparison_status" -eq 0 ] || return "$comparison_status"
    case "$comparison" in
        same)
            dotfiles_config_print_result unchanged public
            return 0
            ;;
        different) ;;
        *)
            printf 'error: local selection comparison returned an invalid result\n' >&2
            return 4
            ;;
    esac

    printf 'Save this local selection? Type yes to continue:\n'
    if ! IFS= read -r answer || [ "$answer" != yes ]; then
        printf 'Cancelled. Local selection was not changed.\n'
        printf 'Managed home configuration: unchanged.\n'
        return 0
    fi

    dotfiles_config_state_set "$profile" "$modules" "$additional" "$platform"
)
