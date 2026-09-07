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
    local suite runner suite_directory manifest manifest_lines manifest_set actual actual_set
    local source_count leaf relative leaf_definitions definitions duplicate expected_mode mode_entry
    local safety_root suite_function failed=0

    safety_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-support-safety.XXXXXX") || return 1
    while IFS= read -r suite; do
        runner="${repository_root%/}/tests/${suite}.sh"
        suite_directory="${repository_root%/}/tests/${suite}"
        manifest=$(sed -n 's/^# test-suite-manifest: //p' "$runner")
        manifest_lines=$(printf '%s\n' $manifest)
        actual=$(sed -n 's#^source "\$DOTFILES_TEST_SUITE_DIR/\([^"/]*\.sh\)"$#\1#p' "$runner")
        source_count=$(grep -Ec '^[[:space:]]*(source|\.)[[:space:]]' "$runner" 2>/dev/null || true)
        if [ -z "$manifest" ] || [ "${manifest_lines%%$'\n'*}" != support.sh ] ||
            [ "$actual" != "$manifest_lines" ] || [ "$source_count" -ne 5 ]; then
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
                    < <(find "$suite_directory" -type f -print | LC_ALL=C sort)
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
            leaf_definitions=$(awk '
                /^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*/ {
                    name=$0; sub(/^[[:space:]]*function[[:space:]]+/, "", name)
                    sub(/[[:space:]({].*$/, "", name); print name; next
                }
                /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)/ {
                    name=$0; sub(/^[[:space:]]*/, "", name)
                    sub(/[[:space:]]*\(\).*/, "", name); print name
                }
            ' "$leaf")
            if [ "$relative" != support.sh ] && [ -n "$leaf_definitions" ]; then
                printf 'error: test case defines a suite-local function: tests/%s/%s\n' "$suite" "$relative" >&2
                failed=1
            fi
            definitions="${definitions}${definitions:+$'\n'}${leaf_definitions}"
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
        case "$suite" in config-state|config-inspection|maintainability) expected_mode=644 ;; esac
        if [ "$(test_file_mode "$runner")" != "$expected_mode" ]; then
            printf 'error: stable test runner mode is invalid: tests/%s.sh\n' "$suite" >&2
            failed=1
        fi
        if ! grep -Fqx 'SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)' "$runner"; then
            printf 'error: test runner physical-path bootstrap is invalid: tests/%s.sh\n' "$suite" >&2
            failed=1
        fi
        suite_function=${suite//-/_}
        if ! awk -v allocate="${suite_function}_allocate_root" -v initialize="${suite_function}_initialize" '
            $0 == allocate { allocate_line=NR }
            $0 == "trap cleanup EXIT" { trap_line=NR }
            $0 == initialize { initialize_line=NR }
            END { exit !(allocate_line && trap_line == allocate_line + 1 && initialize_line == trap_line + 1) }
        ' "$runner"; then
            printf 'error: test runner cleanup must immediately protect initialization: tests/%s.sh\n' "$suite" >&2
            failed=1
        fi
    done < <(decomposed_test_suites)
    for mode_entry in run.sh:755 render.sh:644 plan.sh:755 maintainability.sh:644; do
        relative=${mode_entry%%:*}
        expected_mode=${mode_entry#*:}
        [ ! -e "${repository_root%/}/tests/$relative" ] ||
            [ "$(test_file_mode "${repository_root%/}/tests/$relative")" = "$expected_mode" ] || {
                printf 'error: stable test runner mode is invalid: tests/%s\n' "$relative" >&2
                failed=1
            }
    done
    rm -rf -- "$safety_root"
    [ "$failed" -eq 0 ]
}

check_test_syntax() {
    local repository_root=$1 file relative failed=0
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
    local actual expected
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
