#!/usr/bin/env bash

# Production shell architecture guard. Functions are sourceable by the focused
# test suite; direct execution always validates this repository.

production_shell_paths() {
    local repository_root=$1

    printf '%s\n' "${repository_root%/}/bin/dotfiles"
    find "${repository_root%/}/lib" -type f -name '*.sh' -print | LC_ALL=C sort
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
        measured=$(awk 'END { print NR + 0 }' "$file") || return 1
        if [ "$measured" -gt "$allowed" ]; then
            printf 'error: production shell line budget exceeded: %s has %s lines (allowed %s)\n' \
                "$relative" "$measured" "$allowed" >&2
            failed=1
        fi
    done < <(production_shell_paths "$repository_root")

    [ "$failed" -eq 0 ]
}

check_production_modes() {
    local repository_root=$1
    local relative
    local file
    local failed=0

    for relative in bin/dotfiles scripts/check.sh scripts/check-maintainability.sh; do
        if [ ! -x "${repository_root%/}/$relative" ]; then
            printf 'error: required executable mode is missing: %s\n' "$relative" >&2
            failed=1
        fi
    done
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if [ -x "$file" ]; then
            relative=${file#"${repository_root%/}/"}
            printf 'error: source-only library must not be executable: %s\n' "$relative" >&2
            failed=1
        fi
    done < <(find "${repository_root%/}/lib" -type f -name '*.sh' -print | LC_ALL=C sort)

    [ "$failed" -eq 0 ]
}

check_production_syntax() {
    local repository_root=$1
    local file
    local relative
    local failed=0

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if ! bash -n "$file" >/dev/null 2>&1; then
            relative=${file#"${repository_root%/}/"}
            printf 'error: production shell syntax is invalid: %s\n' "$relative" >&2
            failed=1
        fi
    done < <(production_shell_paths "$repository_root")

    [ "$failed" -eq 0 ]
}

check_fixed_loaders() {
    local repository_root=$1
    local cli_loader="${repository_root%/}/lib/cli.sh"
    local state_loader="${repository_root%/}/lib/config-state.sh"
    local actual
    local expected
    local source_count
    local relative
    local leaf
    local failed=0

    expected='cli/common.sh
cli/catalog.sh
cli/selection.sh
cli/config-commands.sh
cli/execution-commands.sh'
    actual=$(sed -n 's#^source "\$DOTFILES_CLI_LOADER_DIR/\([^"]*\.sh\)" || {$#\1#p' "$cli_loader")
    source_count=$(grep -Ec '^[[:space:]]*source[[:space:]]' "$cli_loader" 2>/dev/null || true)
    if [ "$actual" != "$expected" ] || [ "$source_count" -ne 5 ]; then
        printf 'error: fixed CLI loader order or membership is invalid: lib/cli.sh\n' >&2
        failed=1
    fi
    if grep -Eq '^[[:space:]]*(eval|\.)[[:space:]]' "$cli_loader"; then
        printf 'error: dynamic CLI loader syntax is prohibited: lib/cli.sh\n' >&2
        failed=1
    fi
    while IFS= read -r relative; do
        leaf="${repository_root%/}/lib/$relative"
        if [ ! -f "$leaf" ]; then
            printf 'error: fixed CLI loader leaf is missing: lib/%s\n' "$relative" >&2
            failed=1
            continue
        fi
        if grep -Eq '^[[:space:]]*(source|\.)[[:space:]].*(DOTFILES_CLI_LOADER_DIR|/cli/|/cli\.sh)' \
            "$leaf"; then
            printf 'error: CLI loader leaf contains a facade or sibling source edge: lib/%s\n' \
                "$relative" >&2
            failed=1
        fi
    done <<< "$expected"

    expected='config-state/schema.sh
config-state/storage.sh
config-state/reader.sh
config-state/lock.sh
config-state/writer.sh'
    actual=$(sed -n 's#^source "\$DOTFILES_CONFIG_STATE_LOADER_DIR/\([^"]*\.sh\)" || {$#\1#p' "$state_loader")
    source_count=$(grep -Ec '^[[:space:]]*source[[:space:]]' "$state_loader" 2>/dev/null || true)
    if [ "$actual" != "$expected" ] || [ "$source_count" -ne 5 ]; then
        printf 'error: fixed config-state loader order or membership is invalid: lib/config-state.sh\n' >&2
        failed=1
    fi
    if grep -Eq '^[[:space:]]*(eval|\.)[[:space:]]' "$state_loader"; then
        printf 'error: dynamic config-state loader syntax is prohibited: lib/config-state.sh\n' >&2
        failed=1
    fi
    while IFS= read -r relative; do
        leaf="${repository_root%/}/lib/$relative"
        if [ ! -f "$leaf" ]; then
            printf 'error: fixed config-state loader leaf is missing: lib/%s\n' "$relative" >&2
            failed=1
            continue
        fi
        if grep -Eq '^[[:space:]]*(source|\.)[[:space:]].*(DOTFILES_CONFIG_STATE_LOADER_DIR|/config-state/|/config-state\.sh)' \
            "$leaf"; then
            printf 'error: config-state loader leaf contains a facade or sibling source edge: lib/%s\n' \
                "$relative" >&2
            failed=1
        fi
    done <<< "$expected"

    [ "$failed" -eq 0 ]
}

check_duplicate_function_definitions() {
    local repository_root=$1
    local definitions
    local duplicates
    local duplicate
    local paths
    local file
    local relative
    local failed=0

    definitions=$(
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            relative=${file#"${repository_root%/}/"}
            awk -v path="$relative" '
                /^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ {
                    name = $0
                    sub(/\(\).*/, "", name)
                    print name "\t" path
                }
            ' "$file"
        done < <(production_shell_paths "$repository_root")
    )
    duplicates=$(printf '%s\n' "$definitions" | awk -F '\t' 'NF == 2 { print $1 }' | LC_ALL=C sort | uniq -d)
    while IFS= read -r duplicate; do
        [ -n "$duplicate" ] || continue
        paths=$(printf '%s\n' "$definitions" | awk -F '\t' -v name="$duplicate" '$1 == name { print $2 }' | paste -sd ',' -)
        printf 'error: duplicate production function %s: %s\n' "$duplicate" "$paths" >&2
        failed=1
    done <<< "$duplicates"

    [ "$failed" -eq 0 ]
}

maintainability_main() (
    set -u
    local script_dir
    local repository_root
    local failed=0

    script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
    repository_root=$(CDPATH= cd -- "${script_dir}/.." && pwd -P) || exit 1
    check_production_line_budgets "$repository_root" || failed=1
    check_production_modes "$repository_root" || failed=1
    check_production_syntax "$repository_root" || failed=1
    check_fixed_loaders "$repository_root" || failed=1
    check_duplicate_function_definitions "$repository_root" || failed=1
    [ "$failed" -eq 0 ]
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    maintainability_main "$@"
fi
