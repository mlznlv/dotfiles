# Source-only canonical schema-1 selection validation, serialization, and parsing.

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

dotfiles_config_parse_body() {
    local body=$1
    local byte_count=$2
    local line
    local base_value
    local additional_value
    local expected_size
    local profile=
    local modules=
    local additional=
    local LC_ALL=C
    local -a lines=()

    while IFS= read -r line || [ -n "$line" ]; do
        lines+=("$line")
    done <<< "$body" || return 1

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
    [ "$body" = "$DOTFILES_CONFIG_BODY" ] || return 1
    expected_size=$((${#DOTFILES_CONFIG_BODY} + 1))
    [ "$byte_count" -eq "$expected_size" ] 2>/dev/null || return 1

    DOTFILES_CONFIG_PARSED_PROFILE=$profile
    DOTFILES_CONFIG_PARSED_MODULES=$modules
    DOTFILES_CONFIG_PARSED_ADDITIONAL=$additional
}

dotfiles_config_parse_file() {
    local file=$1
    local actual_body
    local byte_count

    actual_body=$(< "$file") || return 1
    byte_count=$(LC_ALL=C wc -c < "$file") || return 1
    byte_count=${byte_count//[[:space:]]/}
    dotfiles_config_parse_body "$actual_body" "$byte_count"
}
