maintained_file_limit() {
    local repository_root=$1
    local file=$2
    local relative=${file#"${repository_root%/}/"}
    local runner_directory

    case "$relative" in
        bin/dotfiles)
            printf '%s\n' 250
            return
            ;;
        scripts/check-maintainability.sh|tests/maintainability.sh)
            printf '%s\n' 150
            return
            ;;
        tests/*.sh)
            runner_directory=${file%.sh}
            if [ "${file#"${repository_root%/}/tests/"}" = "$(basename -- "$file")" ] &&
                [ -d "$runner_directory" ]; then
                printf '%s\n' 150
                return
            fi
            ;;
    esac
    printf '%s\n' 500
}

maintained_file_has_nul() {
    LC_ALL=C od -An -v -t u1 "$1" | awk '
        { for (field = 1; field <= NF; field++) if ($field == 0) found = 1 }
        END { exit !found }
    '
}

maintained_file_has_long_line() {
    LC_ALL=C awk '
        length($0) > 1000 { found = 1 }
        END { exit !found }
    ' "$1"
}

check_maintained_file_policy() {
    local repository_root=$1
    local file
    local relative
    local measured
    local allowed
    local failed=0

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        relative=$(repository_relative_path "$repository_root" "$file")
        allowed=$(maintained_file_limit "$repository_root" "$file")
        measured=$(physical_line_count "$file") || return 1
        if [ "$measured" -gt "$allowed" ]; then
            maintainability_diagnostic \
                "maintained file line budget exceeded: $relative has $measured lines (allowed $allowed)"
            failed=1
        fi
        if maintained_file_has_nul "$file"; then
            maintainability_diagnostic "maintained file must use a text encoding: $relative"
            failed=1
        elif maintained_file_has_long_line "$file"; then
            maintainability_diagnostic \
                "maintained file contains a line longer than 1000 bytes: $relative"
            failed=1
        fi
    done < <(maintained_file_paths "$repository_root")

    [ "$failed" -eq 0 ]
}

check_test_line_budgets() {
    local repository_root=$1
    local file
    local relative
    local runner_directory
    local measured
    local allowed
    local failed=0

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        relative=${file#"${repository_root%/}/"}
        allowed=500
        runner_directory=${file%.sh}
        if [ "${file#"${repository_root%/}/tests/"}" = "$(basename -- "$file")" ] &&
            [ -d "$runner_directory" ]; then
            allowed=150
        fi
        measured=$(physical_line_count "$file") || return 1
        if [ "$measured" -gt "$allowed" ]; then
            printf 'error: test shell line budget exceeded: %s has %s lines (allowed %s)\n' \
                "$relative" "$measured" "$allowed" >&2
            failed=1
        fi
    done < <(test_shell_paths "$repository_root")

    [ "$failed" -eq 0 ]
}

check_production_line_budgets() {
    local repository_root=$1
    local file
    local relative
    local measured
    local allowed
    local failed=0

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        relative=${file#"${repository_root%/}/"}
        allowed=500
        [ "$relative" != bin/dotfiles ] || allowed=250
        measured=$(physical_line_count "$file") || return 1
        if [ "$measured" -gt "$allowed" ]; then
            printf 'error: production shell line budget exceeded: %s has %s lines (allowed %s)\n' \
                "$relative" "$measured" "$allowed" >&2
            failed=1
        fi
    done < <(production_shell_paths "$repository_root")

    [ "$failed" -eq 0 ]
}
