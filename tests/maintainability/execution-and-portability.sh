run_command bash "${PROJECT_ROOT}/scripts/check-maintainability.sh"
check_status 'final production tree passes the complete maintainability guard' 0
check_equal 'successful maintainability guard is silent' "$OUTPUT" ''
output=$(test_initialization_interruptions_cleanup "$PROJECT_ROOT" "${TEST_ROOT}/initialization interruption" 2>&1)
STATUS=$?
OUTPUT=$output
check_status 'interrupted suite initialization cleans every allocated test root' 0

source_work="${TEST_ROOT}/source work"
mkdir -p "$source_work"
printf 'unchanged\n' > "$source_work/marker"
source_index=0
while IFS= read -r source_target; do
    [ -n "$source_target" ] || continue
    source_index=$((source_index + 1))
    relative_target=${source_target#"${PROJECT_ROOT}/"}
    if source_is_side_effect_free "$source_target" "$source_work" "source-${source_index}"; then
        pass "source-only loading is silent and side-effect free: ${relative_target}"
    else
        STATUS=1
        OUTPUT=$relative_target
        fail "source-only loading is silent and side-effect free: ${relative_target}"
    fi
done < <(
    find "${PROJECT_ROOT}/lib" -type f -name '*.sh' -print | LC_ALL=C sort
)

trace=$(PS4='+' bash -x "${PROJECT_ROOT}/bin/dotfiles" version 2>&1 >/dev/null)
main_calls=$(printf '%s\n' "$trace" | grep -c '^+main version$' || true)
check_equal 'direct execution calls main exactly once' "$main_calls" 1
trace=$(PS4='+' bash -x -c 'source "$1"' maintainability-source "${PROJECT_ROOT}/bin/dotfiles" 2>&1)
main_calls=$(printf '%s\n' "$trace" | grep -c '^+main ' || true)
check_equal 'sourcing the entrypoint never calls main' "$main_calls" 0

arbitrary_cwd="${TEST_ROOT}/different current directory"
space_repository="${TEST_ROOT}/repository path [fixed] !"
mkdir -p "$arbitrary_cwd" "$space_repository"
cp -R "${PROJECT_ROOT}/bin" "$space_repository/bin"
cp -R "${PROJECT_ROOT}/lib" "$space_repository/lib"
cp -R "${PROJECT_ROOT}/.chezmoidata" "$space_repository/.chezmoidata"
cp -R "${PROJECT_ROOT}/home" "$space_repository/home"
cp -R "${PROJECT_ROOT}/tests" "$space_repository/tests"

run_from_directory "$arbitrary_cwd" "${PROJECT_ROOT}/bin/dotfiles" help
check_status 'help runs from an arbitrary current directory' 0
reference_help=$STDOUT
expected_help='Usage:
  dotfiles help
  dotfiles version
  dotfiles catalog validate
  dotfiles module list [--platform macos|debian | --all]
  dotfiles module show <module-id>
  dotfiles profile list [--platform macos|debian | --all]
  dotfiles profile show <profile-id>
  dotfiles resolve [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]
  dotfiles config set (--profile <profile-id> | --modules <id,id>) [--add <id,id>] [--platform macos|debian]
  dotfiles config interactive [--platform macos|debian]
  dotfiles config inspect [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]
  dotfiles config doctor [--platform macos|debian]
  dotfiles prerequisite check [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]
  dotfiles plan [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]
  dotfiles apply [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian] [--yes]

Config set changes only private local selection state. Apply changes only confirmed selected configuration.
Config interactive requires terminal stdin and changes only confirmed private local selection state.
Config inspect and doctor are read-only and diagnose only selection intent and its catalog composition.
Resolve, prerequisite check, plan, and apply load saved selection only when an explicit base is omitted.'
check_equal 'help output remains byte-for-byte stable' "$reference_help" "$expected_help"
run_from_directory "$arbitrary_cwd" "$space_repository/bin/dotfiles" help
check_status 'help loads from a repository path with spaces and metacharacters' 0
check_equal 'copied-path help output is byte-identical' "$STDOUT" "$reference_help"
run_from_directory "$arbitrary_cwd" "$space_repository/bin/dotfiles" version
check_status 'version loads from a repository path with spaces and metacharacters' 0
check_equal 'copied-path version output is exact' "$STDOUT" 'dotfiles 0.1.0-dev'
run_from_directory "$arbitrary_cwd" "$space_repository/bin/dotfiles" resolve --profile shell.minimal --platform debian
check_status 'representative resolution loads from a copied arbitrary path' 0
check_equal 'copied-path representative resolution is exact' "$STDOUT" 'shell.zsh
shell.zsh.autosuggestions
prompt.starship'
run_from_directory "$arbitrary_cwd" env \
    XDG_CONFIG_HOME="${TEST_ROOT}/copied missing state" HOME="${TEST_ROOT}/copied missing home" \
    "$space_repository/bin/dotfiles" config doctor --platform debian
check_status 'config-state facade loads from a copied path with shell metacharacters' 3
check_contains 'copied-path state facade reaches the unchanged missing-state diagnostic' \
    'error: no local selection is configured under $XDG_CONFIG_HOME/dotfiles'

for suite in config-state config-interactive config-consumption config-inspection apply; do
    run_from_directory "$arbitrary_cwd" bash "$space_repository/tests/${suite}.sh"
    check_status "${suite} runner works from a copied metacharacter path and arbitrary CWD" 0
    check_equal "${suite} copied runner preserves stderr" "$STDERR" ''
    digest=$(printf '%s\n' "$STDOUT" | output_sha256)
    check_equal "${suite} copied runner preserves byte-exact baseline output" \
        "$digest" "$(expected_suite_hash "$suite")"
done

missing_cli_repository="${TEST_ROOT}/missing cli leaf"
mkdir -p "$missing_cli_repository"
cp -R "${PROJECT_ROOT}/bin" "$missing_cli_repository/bin"
cp -R "${PROJECT_ROOT}/lib" "$missing_cli_repository/lib"
rm -f "$missing_cli_repository/lib/cli/catalog.sh"
run_from_directory "$arbitrary_cwd" "$missing_cli_repository/bin/dotfiles" help
check_status 'missing required CLI leaf fails closed with status 4' 4
check_equal 'missing CLI leaf produces no partial stdout' "$STDOUT" ''
check_equal 'missing CLI leaf diagnostic is concise' "$STDERR" \
    'error: required CLI component catalog is unavailable'
check_not_contains 'missing CLI leaf diagnostic hides its private copied path' "$missing_cli_repository"

unreadable_state_repository="${TEST_ROOT}/unreadable state leaf"
mkdir -p "$unreadable_state_repository"
cp -R "${PROJECT_ROOT}/bin" "$unreadable_state_repository/bin"
cp -R "${PROJECT_ROOT}/lib" "$unreadable_state_repository/lib"
chmod 000 "$unreadable_state_repository/lib/config-state/reader.sh"
run_from_directory "$arbitrary_cwd" env \
    XDG_CONFIG_HOME="${TEST_ROOT}/missing state" HOME="${TEST_ROOT}/missing home" \
    "$unreadable_state_repository/bin/dotfiles" config doctor --platform debian
check_status 'unreadable required state leaf fails closed with status 4' 4
check_equal 'unreadable state leaf produces no healthy stdout' "$STDOUT" ''
check_equal 'unreadable state leaf diagnostic is concise' "$STDERR" \
    'error: required local selection state component reader is unavailable'
check_not_contains 'unreadable state diagnostic hides its private copied path' "$unreadable_state_repository"

governed_fixture="${TEST_ROOT}/governed file classes"
mkdir -p \
    "$governed_fixture/.chezmoidata/modules" \
    "$governed_fixture/.github/workflows" \
    "$governed_fixture/bin" \
    "$governed_fixture/home" \
    "$governed_fixture/lib" \
    "$governed_fixture/scripts" \
    "$governed_fixture/tests"
for governed_path in \
    .chezmoidata/modules/example.toml \
    .github/workflows/example.yml \
    bin/extensionless \
    home/dot_example.tmpl \
    lib/example.awk \
    scripts/example.py \
    scripts/example.sh \
    tests/example.sh; do
    awk 'BEGIN { for (line = 1; line <= 501; line++) print "# fixture" }' > \
        "$governed_fixture/$governed_path"
done
chmod 755 "$governed_fixture/bin/extensionless"
awk 'BEGIN { for (line = 1; line <= 500; line++) print "# fixture"; printf "# final" }' > \
    "$governed_fixture/tests/no-final-newline"
output=$(check_maintained_file_policy "$governed_fixture" 2>&1)
STATUS=$?
OUTPUT=$output
check_status 'every oversized governed file class fails the general line guard' 1
for governed_path in \
    .chezmoidata/modules/example.toml \
    .github/workflows/example.yml \
    bin/extensionless \
    home/dot_example.tmpl \
    lib/example.awk \
    scripts/example.py \
    scripts/example.sh \
    tests/example.sh \
    tests/no-final-newline; do
    check_contains "general line guard measures ${governed_path}" \
        "error: maintained file line budget exceeded: ${governed_path} has 501 lines (allowed 500)"
done
check_not_contains 'general line diagnostics hide their private fixture root' "$governed_fixture"

special_budget_fixture="${TEST_ROOT}/special line budgets"
mkdir -p \
    "$special_budget_fixture/bin" \
    "$special_budget_fixture/scripts" \
    "$special_budget_fixture/tests/example"
awk 'BEGIN { for (line = 1; line <= 251; line++) print "# fixture" }' > \
    "$special_budget_fixture/bin/dotfiles"
awk 'BEGIN { for (line = 1; line <= 151; line++) print "# fixture" }' > \
    "$special_budget_fixture/scripts/check-maintainability.sh"
awk 'BEGIN { for (line = 1; line <= 151; line++) print "# fixture" }' > \
    "$special_budget_fixture/tests/maintainability.sh"
awk 'BEGIN { for (line = 1; line <= 151; line++) print "# fixture" }' > \
    "$special_budget_fixture/tests/example.sh"
output=$(check_maintained_file_policy "$special_budget_fixture" 2>&1)
STATUS=$?
OUTPUT=$output
check_status 'all special entrypoint line budgets are enforced' 1
check_contains 'bin entrypoint keeps its 250-line budget' \
    'error: maintained file line budget exceeded: bin/dotfiles has 251 lines (allowed 250)'
check_contains 'maintainability checker entrypoint keeps its 150-line budget' \
    'error: maintained file line budget exceeded: scripts/check-maintainability.sh has 151 lines (allowed 150)'
check_contains 'maintainability test entrypoint keeps its 150-line budget' \
    'error: maintained file line budget exceeded: tests/maintainability.sh has 151 lines (allowed 150)'
check_contains 'decomposed stable test runners keep their 150-line budget' \
    'error: maintained file line budget exceeded: tests/example.sh has 151 lines (allowed 150)'

bypass_fixture="${TEST_ROOT}/encoding and minification bypasses"
mkdir -p "$bypass_fixture/lib"
awk 'BEGIN { for (byte = 1; byte <= 1001; byte++) printf "x"; print "" }' > \
    "$bypass_fixture/lib/minified.js"
printf 'text\000data\n' > "$bypass_fixture/lib/binary.data"
output=$(check_maintained_file_policy "$bypass_fixture" 2>&1)
STATUS=$?
OUTPUT=$output
check_status 'minified and binary bypass attempts fail closed' 1
check_contains 'overlong physical lines cannot bypass decomposition' \
    'error: maintained file contains a line longer than 1000 bytes: lib/minified.js'
check_contains 'binary encoding cannot bypass the source policy' \
    'error: maintained file must use a text encoding: lib/binary.data'

line_count=$(physical_line_count "$governed_fixture/tests/no-final-newline")
check_equal 'portable physical line counting includes a final unterminated line' "$line_count" 501
relative_path=$(repository_relative_path "$governed_fixture" \
    "$governed_fixture/tests/no-final-newline")
check_equal 'shared path normalization remains repository-relative' "$relative_path" \
    'tests/no-final-newline'

output=$(check_catalog_program_loader "$PROJECT_ROOT" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'production catalog program manifest is exact' 0
check_equal 'successful catalog program architecture check is silent' "$output" ''
output=$(check_maintainability_loader "$PROJECT_ROOT" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'production maintainability module manifest is exact' 0
check_equal 'successful maintainability module architecture check is silent' "$output" ''

catalog_layout_fixture="${TEST_ROOT}/missing catalog leaf"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
rm -f "$catalog_layout_fixture/lib/catalog/resolution.awk"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'missing catalog program leaf is rejected' 1
check_contains 'missing catalog leaf diagnostic is repository-relative' \
    'error: fixed catalog program leaf is unavailable: lib/catalog/resolution.awk'

catalog_layout_fixture="${TEST_ROOT}/duplicate catalog manifest"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
sed -i.bak 's/catalog\/common.awk /catalog\/common.awk catalog\/common.awk /' \
    "$catalog_layout_fixture/lib/cli/catalog.sh"
rm -f "$catalog_layout_fixture/lib/cli/catalog.sh.bak"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'duplicate catalog manifest membership is rejected' 1
check_contains 'duplicate catalog membership has a focused diagnostic' \
    'error: duplicate fixed catalog program membership: lib/cli/catalog.sh'

catalog_layout_fixture="${TEST_ROOT}/unlisted catalog leaf"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
printf '%s\n' 'unlisted catalog leaf' > \
    "$catalog_layout_fixture/lib/catalog/orphan.data"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'unlisted catalog program leaf is rejected' 1
check_contains 'unlisted catalog leaf diagnostic names its owned directory' \
    'error: fixed catalog program leaf set is invalid: lib/catalog'

catalog_layout_fixture="${TEST_ROOT}/dynamic catalog loader"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
printf '%s\n' '        -f "$CATALOG_PROGRAM_DIRECTORY/"*.awk \' >> \
    "$catalog_layout_fixture/lib/cli/catalog.sh"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'wildcard catalog loading is rejected' 1
check_contains 'wildcard catalog loading has a focused diagnostic' \
    'error: fixed catalog program order or membership is invalid: lib/cli/catalog.sh'

catalog_layout_fixture="${TEST_ROOT}/sibling catalog include"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
printf '%s\n' '@include "output.awk"' >> "$catalog_layout_fixture/lib/catalog/common.awk"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'sibling catalog loading is rejected' 1
check_contains 'sibling catalog loading identifies its leaf' \
    'error: catalog leaf is not function-only: lib/catalog/common.awk'

catalog_layout_fixture="${TEST_ROOT}/circular catalog include"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
printf '%s\n' '@include "../catalog.awk"' >> "$catalog_layout_fixture/lib/catalog/output.awk"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'circular catalog loading is rejected' 1
check_contains 'circular catalog loading identifies its leaf' \
    'error: catalog leaf is not function-only: lib/catalog/output.awk'

catalog_layout_fixture="${TEST_ROOT}/duplicate catalog function"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
printf '%s\n' 'function duplicate_catalog_owner() {' '    return 0' '}' >> \
    "$catalog_layout_fixture/lib/catalog/common.awk"
printf '%s\n' 'function duplicate_catalog_owner() {' '    return 0' '}' >> \
    "$catalog_layout_fixture/lib/catalog/output.awk"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'duplicate catalog function ownership is rejected' 1
check_contains 'duplicate catalog function diagnostic identifies both owners' \
    'error: duplicate catalog function duplicate_catalog_owner: lib/catalog/common.awk,lib/catalog/output.awk'

catalog_layout_fixture="${TEST_ROOT}/catalog helper in entry"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
printf '%s\n' 'function misplaced_helper() {' '    return 0' '}' >> \
    "$catalog_layout_fixture/lib/catalog.awk"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'catalog entry helper ownership is rejected' 1
check_contains 'catalog entry helper diagnostic is focused' \
    'error: catalog entry contains a helper function: lib/catalog.awk'

checker_layout_fixture="${TEST_ROOT}/missing maintainability leaf"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
rm -f "$checker_layout_fixture/scripts/maintainability/file-sizes.sh"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'missing maintainability leaf is rejected' 1
check_contains 'missing maintainability leaf diagnostic is repository-relative' \
    'error: fixed maintainability loader leaf is unavailable: scripts/maintainability/file-sizes.sh'

checker_layout_fixture="${TEST_ROOT}/duplicate maintainability manifest"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
sed -i.bak 's/common.sh /common.sh common.sh /' \
    "$checker_layout_fixture/scripts/check-maintainability.sh"
rm -f "$checker_layout_fixture/scripts/check-maintainability.sh.bak"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'duplicate maintainability manifest membership is rejected' 1
check_contains 'duplicate maintainability membership has a focused diagnostic' \
    'error: duplicate fixed maintainability loader membership: scripts/check-maintainability.sh'

checker_layout_fixture="${TEST_ROOT}/unlisted maintainability leaf"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
printf '%s\n' 'unlisted maintainability leaf' > \
    "$checker_layout_fixture/scripts/maintainability/orphan.data"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'unlisted maintainability leaf is rejected' 1
check_contains 'unlisted maintainability leaf diagnostic names its owned directory' \
    'error: fixed maintainability loader leaf set is invalid: scripts/maintainability'

checker_layout_fixture="${TEST_ROOT}/dynamic maintainability loader"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
printf '%s\n' 'source "$MAINTAINABILITY_LOADER_DIR/"*.sh' >> \
    "$checker_layout_fixture/scripts/check-maintainability.sh"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'wildcard maintainability loading is rejected' 1
check_contains 'wildcard maintainability loading has a focused diagnostic' \
    'error: fixed maintainability loader order or membership is invalid: scripts/check-maintainability.sh'

checker_layout_fixture="${TEST_ROOT}/sibling maintainability source"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
printf '%s\n' 'misplaced_source() {' \
    '    source "$MAINTAINABILITY_LOADER_DIR/common.sh"' '}' >> \
    "$checker_layout_fixture/scripts/maintainability/file-sizes.sh"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'sibling maintainability loading is rejected' 1
check_contains 'sibling maintainability loading identifies its leaf' \
    'error: maintainability leaf contains an execution or source edge: scripts/maintainability/file-sizes.sh'

checker_layout_fixture="${TEST_ROOT}/circular maintainability source"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
printf '%s\n' 'misplaced_source() {' \
    '    source "$MAINTAINABILITY_SCRIPT_DIR/check-maintainability.sh"' '}' >> \
    "$checker_layout_fixture/scripts/maintainability/test-shell.sh"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'circular maintainability loading is rejected' 1
check_contains 'circular maintainability loading identifies its leaf' \
    'error: maintainability leaf contains an execution or source edge: scripts/maintainability/test-shell.sh'

checker_layout_fixture="${TEST_ROOT}/duplicate maintainability function"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
printf '%s\n' 'duplicate_maintainability_owner() {' '    :' '}' >> \
    "$checker_layout_fixture/scripts/maintainability/common.sh"
printf '%s\n' 'duplicate_maintainability_owner() {' '    :' '}' >> \
    "$checker_layout_fixture/scripts/maintainability/file-sizes.sh"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'duplicate maintainability function ownership is rejected' 1
check_contains 'duplicate maintainability function diagnostic identifies both owners' \
    'error: duplicate maintainability function duplicate_maintainability_owner: scripts/maintainability/common.sh,scripts/maintainability/file-sizes.sh'

checker_layout_fixture="${TEST_ROOT}/maintainability top-level action"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
printf '%s\n' 'printf "unexpected action\\n"' >> \
    "$checker_layout_fixture/scripts/maintainability/common.sh"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'top-level maintainability leaf action is rejected' 1
check_contains 'top-level maintainability action identifies its leaf' \
    'error: maintainability leaf contains an execution or source edge: scripts/maintainability/common.sh'

catalog_runtime_fixture="${TEST_ROOT}/missing catalog runtime leaf"
mkdir -p "$catalog_runtime_fixture"
cp -R "${PROJECT_ROOT}/bin" "$catalog_runtime_fixture/bin"
cp -R "${PROJECT_ROOT}/lib" "$catalog_runtime_fixture/lib"
rm -f "$catalog_runtime_fixture/lib/catalog/resolution.awk"
run_from_directory "$arbitrary_cwd" env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" \
    "$catalog_runtime_fixture/bin/dotfiles" catalog validate
check_status 'missing catalog runtime leaf fails closed with status 4' 4
check_equal 'missing catalog runtime leaf produces no healthy stdout' "$STDOUT" ''
check_equal 'missing catalog runtime diagnostic is concise' "$STDERR" \
    'error: required catalog component resolution is unavailable'
check_not_contains 'missing catalog runtime diagnostic hides its copied path' "$catalog_runtime_fixture"

catalog_runtime_fixture="${TEST_ROOT}/unreadable catalog runtime leaf"
mkdir -p "$catalog_runtime_fixture"
cp -R "${PROJECT_ROOT}/bin" "$catalog_runtime_fixture/bin"
cp -R "${PROJECT_ROOT}/lib" "$catalog_runtime_fixture/lib"
chmod 000 "$catalog_runtime_fixture/lib/catalog/output.awk"
run_from_directory "$arbitrary_cwd" env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" \
    "$catalog_runtime_fixture/bin/dotfiles" catalog validate
check_status 'unreadable catalog runtime leaf fails closed with status 4' 4
check_equal 'unreadable catalog runtime leaf produces no healthy stdout' "$STDOUT" ''
check_equal 'unreadable catalog runtime diagnostic is concise' "$STDERR" \
    'error: required catalog component output is unavailable'
check_not_contains 'unreadable catalog runtime diagnostic hides its copied path' "$catalog_runtime_fixture"

checker_runtime_fixture="${TEST_ROOT}/missing checker runtime leaf"
mkdir -p "$checker_runtime_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_runtime_fixture/scripts"
rm -f "$checker_runtime_fixture/scripts/maintainability/common.sh"
run_from_directory "$arbitrary_cwd" bash \
    "$checker_runtime_fixture/scripts/check-maintainability.sh"
check_status 'missing checker runtime leaf fails closed with status 4' 4
check_equal 'missing checker runtime leaf produces no healthy stdout' "$STDOUT" ''
check_equal 'missing checker runtime diagnostic is concise' "$STDERR" \
    'error: required maintainability component common is unavailable'
check_not_contains 'missing checker runtime diagnostic hides its copied path' "$checker_runtime_fixture"

checker_runtime_fixture="${TEST_ROOT}/unreadable checker runtime leaf"
mkdir -p "$checker_runtime_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_runtime_fixture/scripts"
chmod 000 "$checker_runtime_fixture/scripts/maintainability/file-sizes.sh"
run_from_directory "$arbitrary_cwd" bash \
    "$checker_runtime_fixture/scripts/check-maintainability.sh"
check_status 'unreadable checker runtime leaf fails closed with status 4' 4
check_equal 'unreadable checker runtime leaf produces no healthy stdout' "$STDOUT" ''
check_equal 'unreadable checker runtime diagnostic is concise' "$STDERR" \
    'error: required maintainability component file-sizes is unavailable'
check_not_contains 'unreadable checker runtime diagnostic hides its copied path' "$checker_runtime_fixture"

source_index=0
while IFS= read -r source_target; do
    [ -n "$source_target" ] || continue
    source_index=$((source_index + 1))
    relative_target=${source_target#"${PROJECT_ROOT}/"}
    if source_is_side_effect_free "$source_target" "$source_work" \
        "maintainability-source-${source_index}"; then
        pass "maintainability source-only loading is silent and side-effect free: ${relative_target}"
    else
        STATUS=1
        OUTPUT=$relative_target
        fail "maintainability source-only loading is silent and side-effect free: ${relative_target}"
    fi
done < <(
    printf '%s\n' "${PROJECT_ROOT}/scripts/check-maintainability.sh"
    find "${PROJECT_ROOT}/scripts/maintainability" -type f -name '*.sh' -print | LC_ALL=C sort
)

trace=$(PS4='+' bash -x "${PROJECT_ROOT}/scripts/check-maintainability.sh" 2>&1 >/dev/null)
main_calls=$(printf '%s\n' "$trace" | grep -c '^+maintainability_main$' || true)
check_equal 'direct maintainability execution calls main exactly once' "$main_calls" 1
trace=$(PS4='+' bash -x -c 'source "$1"' maintainability-source \
    "${PROJECT_ROOT}/scripts/check-maintainability.sh" 2>&1)
main_calls=$(printf '%s\n' "$trace" | grep -c '^+maintainability_main' || true)
check_equal 'sourcing the maintainability entrypoint never calls main' "$main_calls" 0

cp -R "${PROJECT_ROOT}/scripts" "$space_repository/scripts"
run_from_directory "$arbitrary_cwd" bash "$space_repository/scripts/check-maintainability.sh"
check_status 'maintainability guard runs from a copied metacharacter path and arbitrary CWD' 0
check_equal 'copied-path maintainability success is silent' "$OUTPUT" ''

catalog_layout_fixture="${TEST_ROOT}/environment-selected catalog loader"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
sed -i.bak 's#-f "$CATALOG_PROGRAM_DIRECTORY/common.awk"#-f "$CATALOG_PROGRAM_DIRECTORY/${CATALOG_COMPONENT}.awk"#' \
    "$catalog_layout_fixture/lib/cli/catalog.sh"
rm -f "$catalog_layout_fixture/lib/cli/catalog.sh.bak"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'environment-selected catalog loading is rejected' 1
check_contains 'dynamic catalog loading has a focused diagnostic' \
    'error: fixed catalog program order or membership is invalid: lib/cli/catalog.sh'

checker_layout_fixture="${TEST_ROOT}/environment-selected maintainability loader"
mkdir -p "$checker_layout_fixture"
cp -R "${PROJECT_ROOT}/scripts" "$checker_layout_fixture/scripts"
sed -i.bak 's#/common.sh#/\${MAINTAINABILITY_COMPONENT}.sh#' \
    "$checker_layout_fixture/scripts/check-maintainability.sh"
rm -f "$checker_layout_fixture/scripts/check-maintainability.sh.bak"
output=$(check_maintainability_loader "$checker_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'environment-selected maintainability loading is rejected' 1
check_contains 'dynamic maintainability loading has a focused diagnostic' \
    'error: fixed maintainability loader order or membership is invalid: scripts/check-maintainability.sh'

catalog_layout_fixture="${TEST_ROOT}/catalog pattern in leaf"
mkdir -p "$catalog_layout_fixture"
cp -R "${PROJECT_ROOT}/lib" "$catalog_layout_fixture/lib"
printf '%s\n' 'BEGIN { unexpected = 1 }' >> \
    "$catalog_layout_fixture/lib/catalog/common.awk"
output=$(check_catalog_program_loader "$catalog_layout_fixture" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'catalog leaf record or lifecycle patterns are rejected' 1
check_contains 'catalog pattern ownership identifies its leaf' \
    'error: catalog leaf is not function-only: lib/catalog/common.awk'
