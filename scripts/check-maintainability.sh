#!/usr/bin/env bash

# Production shell architecture guard. Functions are sourceable by the focused
# test suite; direct execution always validates this repository.

production_shell_paths() {
    local repository_root=$1

    printf '%s\n' "${repository_root%/}/bin/dotfiles"
    find "${repository_root%/}/lib" -type f -name '*.sh' -print | LC_ALL=C sort
}

test_shell_paths() {
    local repository_root=$1

    find "${repository_root%/}/tests" -type f -name '*.sh' -print | LC_ALL=C sort
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
        measured=$(awk 'END { print NR + 0 }' "$file") || return 1
        if [ "$measured" -gt "$allowed" ]; then
            printf 'error: test shell line budget exceeded: %s has %s lines (allowed %s)\n' \
                "$relative" "$measured" "$allowed" >&2
            failed=1
        fi
    done < <(test_shell_paths "$repository_root")

    [ "$failed" -eq 0 ]
}

decomposed_test_suites() {
    printf '%s\n' config-state config-inspection config-interactive config-consumption apply
}

test_file_mode() {
    if stat -f '%Lp' "$1" >/dev/null 2>&1; then
        stat -f '%Lp' "$1"
    else
        stat -c '%a' "$1"
    fi
}

test_support_is_source_safe() (
    local support=$1
    local working_directory=$2
    local before_pwd
    local before_ifs
    local before_umask
    local before_options
    local before_option_state
    local before_traps
    local before_tree
    local source_status

    CDPATH= cd -- "$working_directory" || exit 1
    : > .source.stdout
    : > .source.stderr
    before_pwd=$PWD
    before_ifs=$IFS
    before_umask=$(umask)
    before_options=$-
    before_option_state=$(set +o)
    before_traps=$(trap -p)
    before_tree=$(find . -print | LC_ALL=C sort)
    # shellcheck disable=SC1090
    source "$support" > .source.stdout 2> .source.stderr
    source_status=$?
    [ "$source_status" -eq 0 ] && [ ! -s .source.stdout ] && [ ! -s .source.stderr ] &&
        [ "$PWD" = "$before_pwd" ] && [ "$IFS" = "$before_ifs" ] &&
        [ "$(umask)" = "$before_umask" ] && [ "$-" = "$before_options" ] &&
        [ "$(set +o)" = "$before_option_state" ] && [ "$(trap -p)" = "$before_traps" ] &&
        [ "$(find . -print | LC_ALL=C sort)" = "$before_tree" ]
)

check_test_suite_layouts() {
    local repository_root=$1
    local suite
    local runner
    local suite_directory
    local manifest
    local manifest_lines
    local manifest_set
    local actual
    local actual_set
    local source_count
    local leaf
    local relative
    local definitions
    local duplicate
    local expected_mode
    local safety_root
    local failed=0

    safety_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-support-safety.XXXXXX") || return 1
    while IFS= read -r suite; do
        runner="${repository_root%/}/tests/${suite}.sh"
        suite_directory="${repository_root%/}/tests/${suite}"
        manifest=$(sed -n 's/^# test-suite-manifest: //p' "$runner")
        manifest_lines=$(printf '%s\n' $manifest)
        actual=$(sed -n 's#^source "\$DOTFILES_TEST_SUITE_DIR/\([^"/]*\.sh\)"$#\1#p' "$runner")
        source_count=$(grep -Ec '^[[:space:]]*(source|\.)[[:space:]]' "$runner" 2>/dev/null || true)
        if [ -z "$manifest" ] || [ "${manifest_lines%%$'\n'*}" != support.sh ] ||
            [ "$actual" != "$manifest_lines" ] ||
            [ "$source_count" -ne 5 ]; then
            printf 'error: fixed test loader order or membership is invalid: tests/%s.sh\n' "$suite" >&2
            failed=1
        fi
        if [ "$(printf '%s\n' "$manifest_lines" | LC_ALL=C sort | uniq -d)" ]; then
            printf 'error: duplicate fixed test loader membership: tests/%s.sh\n' "$suite" >&2
            failed=1
        fi
        manifest_set=$(printf '%s\n' "$manifest_lines" | LC_ALL=C sort)
        actual_set=$(
            if [ -d "$suite_directory" ]; then
                while IFS= read -r leaf; do printf '%s\n' "${leaf#"${suite_directory}/"}"; done \
                    < <(find "$suite_directory" -type f -name '*.sh' -print | LC_ALL=C sort)
            fi
        )
        if [ "$actual_set" != "$manifest_set" ]; then
            printf 'error: fixed test loader leaf set is invalid: tests/%s\n' "$suite" >&2
            failed=1
        fi
        definitions=
        while IFS= read -r relative; do
            [ -n "$relative" ] || continue
            leaf="${suite_directory}/$relative"
            if [ ! -f "$leaf" ]; then
                printf 'error: fixed test loader leaf is missing: tests/%s/%s\n' "$suite" "$relative" >&2
                failed=1
                continue
            fi
            if [ -x "$leaf" ]; then
                printf 'error: internal test fragment must not be executable: tests/%s/%s\n' "$suite" "$relative" >&2
                failed=1
            fi
            if { [ "$relative" != support.sh ] &&
                 grep -Eq '^[[:space:]]*(source|\.|eval|trap|exit)[[:space:]]' "$leaf"; } ||
               { [ "$relative" = support.sh ] &&
                 grep -Eq '^[[:space:]]*(eval[[:space:]]|\.[[:space:]]|source[[:space:]].*(DOTFILES_TEST_SUITE_DIR|/tests/))' "$leaf"; }; then
                printf 'error: test leaf contains a sibling or dynamic source edge: tests/%s/%s\n' "$suite" "$relative" >&2
                failed=1
            fi
            definitions="${definitions}${definitions:+$'\n'}$(awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ { name=$0; sub(/\(\).*/, "", name); print name }' "$leaf")"
        done <<< "$manifest_lines"
        duplicate=$(printf '%s\n' "$definitions" | sed '/^$/d' | LC_ALL=C sort | uniq -d)
        if [ -n "$duplicate" ]; then
            printf 'error: duplicate test function %s: tests/%s\n' "$duplicate" "$suite" >&2
            failed=1
        fi
        mkdir -p "$safety_root/$suite"
        if ! test_support_is_source_safe "$suite_directory/support.sh" "$safety_root/$suite"; then
            printf 'error: test support is not source-safe: tests/%s/support.sh\n' "$suite" >&2
            failed=1
        fi
        expected_mode=755
        case "$suite" in config-state|config-inspection) expected_mode=644 ;; esac
        if [ "$(test_file_mode "$runner")" != "$expected_mode" ]; then
            printf 'error: stable test runner mode is invalid: tests/%s.sh\n' "$suite" >&2
            failed=1
        fi
        if ! grep -Fqx 'SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)' "$runner"; then
            printf 'error: test runner physical-path bootstrap is invalid: tests/%s.sh\n' "$suite" >&2
            failed=1
        fi
    done < <(decomposed_test_suites)
    rm -rf -- "$safety_root"
    [ "$failed" -eq 0 ]
}

check_test_syntax() {
    local repository_root=$1
    local file
    local relative
    local failed=0
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if ! bash -n "$file" >/dev/null 2>&1; then
            relative=${file#"${repository_root%/}/"}
            printf 'error: test shell syntax is invalid: %s\n' "$relative" >&2
            failed=1
        fi
    done < <(test_shell_paths "$repository_root")
    [ "$failed" -eq 0 ]
}

check_test_execution_manifest() {
    local repository_root=$1
    local check_script="${repository_root%/}/scripts/check.sh"
    local actual
    local expected
    expected='run.sh
config-state.sh
config-interactive.sh
config-consumption.sh
config-inspection.sh
maintainability.sh
render.sh
plan.sh
apply.sh'
    actual=$(sed -n 's#^bash "${PROJECT_ROOT}/tests/\([^"/]*\.sh\)"$#\1#p' "$check_script")
    if [ "$actual" != "$expected" ] || grep -Eq '\$\{PROJECT_ROOT\}/tests/(config-state|config-inspection|config-interactive|config-consumption|apply)/' "$check_script"; then
        printf 'error: stable test execution manifest is invalid: scripts/check.sh\n' >&2
        return 1
    fi
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
    local actual_leaf_set
    local expected
    local expected_leaf_set
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
    expected_leaf_set='cli/catalog.sh
cli/common.sh
cli/config-commands.sh
cli/execution-commands.sh
cli/selection.sh'
    actual_leaf_set=$(
        if [ -d "${repository_root%/}/lib/cli" ]; then
            while IFS= read -r leaf; do
                printf '%s\n' "${leaf#"${repository_root%/}/lib/"}"
            done < <(find "${repository_root%/}/lib/cli" -type f -name '*.sh' -print | LC_ALL=C sort)
        fi
    )
    if [ "$actual_leaf_set" != "$expected_leaf_set" ]; then
        printf 'error: fixed CLI loader leaf set is invalid: lib/cli\n' >&2
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
    expected_leaf_set='config-state/lock.sh
config-state/reader.sh
config-state/schema.sh
config-state/storage.sh
config-state/writer.sh'
    actual_leaf_set=$(
        if [ -d "${repository_root%/}/lib/config-state" ]; then
            while IFS= read -r leaf; do
                printf '%s\n' "${leaf#"${repository_root%/}/lib/"}"
            done < <(find "${repository_root%/}/lib/config-state" -type f -name '*.sh' -print | LC_ALL=C sort)
        fi
    )
    if [ "$actual_leaf_set" != "$expected_leaf_set" ]; then
        printf 'error: fixed config-state loader leaf set is invalid: lib/config-state\n' >&2
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
    check_test_line_budgets "$repository_root" || failed=1
    check_test_suite_layouts "$repository_root" || failed=1
    check_test_syntax "$repository_root" || failed=1
    check_test_execution_manifest "$repository_root" || failed=1
    check_production_modes "$repository_root" || failed=1
    check_production_syntax "$repository_root" || failed=1
    check_fixed_loaders "$repository_root" || failed=1
    check_duplicate_function_definitions "$repository_root" || failed=1
    [ "$failed" -eq 0 ]
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    maintainability_main "$@"
fi
