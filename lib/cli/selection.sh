# Source-only selection parsing, precedence, and inspection presentation.

parse_consuming_selection_options() {
    local command_kind=$1
    local allow_yes=$2
    local option
    shift 2

    DOTFILES_SELECTION_PROFILE=
    DOTFILES_SELECTION_MODULES=
    DOTFILES_SELECTION_ADDITIONAL=
    DOTFILES_SELECTION_PLATFORM=
    DOTFILES_SELECTION_EXPLICIT_BASE=0
    DOTFILES_SELECTION_YES=0
    DOTFILES_SELECTION_HELP=0
    local profile_seen=0
    local modules_seen=0
    local additional_seen=0
    local platform_seen=0
    local yes_seen=0

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
                        DOTFILES_SELECTION_PROFILE=$1
                        ;;
                    --modules)
                        [ "$modules_seen" -eq 0 ] || usage_error "--modules may be specified only once"
                        modules_seen=1
                        DOTFILES_SELECTION_MODULES=$1
                        ;;
                    --add)
                        [ "$additional_seen" -eq 0 ] || usage_error "--add may be specified only once"
                        additional_seen=1
                        DOTFILES_SELECTION_ADDITIONAL=$1
                        ;;
                    --platform)
                        [ "$platform_seen" -eq 0 ] || usage_error "--platform may be specified only once"
                        platform_seen=1
                        DOTFILES_SELECTION_PLATFORM=$1
                        ;;
                esac
                ;;
            --yes)
                [ "$allow_yes" -eq 1 ] || usage_error "unknown ${command_kind} option"
                [ "$yes_seen" -eq 0 ] || usage_error "--yes may be specified only once"
                yes_seen=1
                DOTFILES_SELECTION_YES=1
                ;;
            -h|--help)
                usage
                DOTFILES_SELECTION_HELP=1
                return 0
                ;;
            *) usage_error "unknown ${command_kind} option" ;;
        esac
        shift
    done

    if [ "$profile_seen" -eq 1 ] && [ "$modules_seen" -eq 1 ]; then
        usage_error "--profile and --modules are mutually exclusive"
    fi
    if [ "$profile_seen" -eq 1 ] || [ "$modules_seen" -eq 1 ]; then
        DOTFILES_SELECTION_EXPLICIT_BASE=1
    fi
}
dotfiles_effective_selection() {
    local explicit_base=$1
    local profile=$2
    local modules=$3
    local invocation_additional=$4
    local platform=$5
    local selection_source=explicit
    local state_snapshot=

    DOTFILES_EFFECTIVE_PROFILE=$profile
    DOTFILES_EFFECTIVE_MODULES=$modules
    DOTFILES_EFFECTIVE_ADDITIONAL=$invocation_additional
    DOTFILES_EFFECTIVE_SNAPSHOT=
    DOTFILES_EFFECTIVE_SOURCE=invocation

    if [ "$explicit_base" -eq 0 ]; then
        selection_source=local
        DOTFILES_EFFECTIVE_SOURCE=local
        config_require_state_program || return $?
        dotfiles_config_state_load "$platform" || return $?
        DOTFILES_EFFECTIVE_PROFILE=$DOTFILES_CONFIG_LOADED_PROFILE
        DOTFILES_EFFECTIVE_MODULES=$DOTFILES_CONFIG_LOADED_MODULES
        DOTFILES_EFFECTIVE_ADDITIONAL=$DOTFILES_CONFIG_LOADED_ADDITIONAL
        if [ -n "$invocation_additional" ]; then
            DOTFILES_EFFECTIVE_SOURCE='local plus invocation additions'
            if [ -n "$DOTFILES_EFFECTIVE_ADDITIONAL" ]; then
                DOTFILES_EFFECTIVE_ADDITIONAL="${DOTFILES_EFFECTIVE_ADDITIONAL},${invocation_additional}"
            else
                DOTFILES_EFFECTIVE_ADDITIONAL=$invocation_additional
            fi
        fi
        dotfiles_config_validate_intent "$DOTFILES_EFFECTIVE_PROFILE" \
            "$DOTFILES_EFFECTIVE_MODULES" "$DOTFILES_EFFECTIVE_ADDITIONAL" || return $?
        state_snapshot=$DOTFILES_CONFIG_LOADED_SNAPSHOT
    fi

    DOTFILES_EFFECTIVE_SNAPSHOT="source=${selection_source}
profile=${DOTFILES_EFFECTIVE_PROFILE}
modules=${DOTFILES_EFFECTIVE_MODULES}
additional=${DOTFILES_EFFECTIVE_ADDITIONAL}
${state_snapshot}"
}

config_print_inspection() {
    local source=$1
    local profile=$2
    local modules=$3
    local additional=$4
    local platform=$5
    local resolved_modules=$6
    local resolved_module

    printf 'Selection source: %s\n' "$source"
    if [ -n "$profile" ]; then
        printf 'Base: %s\n' "$profile"
    else
        printf 'Base: %s\n' "$modules"
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
