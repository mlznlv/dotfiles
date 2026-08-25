#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)
TEST_PARENT=${TMPDIR:-/tmp}
TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-maintainability-tests.XXXXXX")

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

# shellcheck source=../scripts/check-maintainability.sh
source "${PROJECT_ROOT}/scripts/check-maintainability.sh"

failures=0
checks=0
STATUS=0
STDOUT=
STDERR=
OUTPUT=

pass() {
    checks=$((checks + 1))
    printf 'ok - %s\n' "$1"
}

fail() {
    checks=$((checks + 1))
    failures=$((failures + 1))
    printf 'not ok - %s\n' "$1"
    printf '  status: %s\n' "$STATUS"
    printf '  output: %s\n' "$OUTPUT"
}

check_status() {
    local name=$1
    local expected=$2
    if [ "$STATUS" -eq "$expected" ]; then pass "$name"; else fail "$name"; fi
}

check_equal() {
    local name=$1
    local actual=$2
    local expected=$3
    if [ "$actual" = "$expected" ]; then
        pass "$name"
    else
        STATUS=1
        OUTPUT="expected: ${expected}; actual: ${actual}"
        fail "$name"
    fi
}

check_contains() {
    local name=$1
    local expected=$2
    case "$OUTPUT" in *"$expected"*) pass "$name" ;; *) STATUS=1; fail "$name" ;; esac
}

check_not_contains() {
    local name=$1
    local rejected=$2
    case "$OUTPUT" in *"$rejected"*) STATUS=1; fail "$name" ;; *) pass "$name" ;; esac
}

run_command() {
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"

    "$@" > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
}

run_from_directory() {
    local directory=$1
    shift
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"

    (
        CDPATH= cd -- "$directory" || exit 1
        "$@"
    ) > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
}

source_is_side_effect_free() (
    local target=$1
    local working_directory=$2
    local tag=$3
    local stdout_file="${TEST_ROOT}/${tag}.stdout"
    local stderr_file="${TEST_ROOT}/${tag}.stderr"
    local before_pwd
    local before_ifs
    local before_umask
    local before_options
    local before_option_state
    local before_traps
    local before_tree
    local after_tree
    local source_status

    : > "$stdout_file"
    : > "$stderr_file"
    CDPATH= cd -- "$working_directory" || exit 1
    before_pwd=$PWD
    before_ifs=$IFS
    before_umask=$(umask)
    before_options=$-
    before_option_state=$(set +o)
    before_traps=$(trap -p)
    before_tree=$(find . -print | LC_ALL=C sort)

    # shellcheck disable=SC1090
    source "$target" > "$stdout_file" 2> "$stderr_file"
    source_status=$?
    after_tree=$(find . -print | LC_ALL=C sort)

    [ "$source_status" -eq 0 ] && [ ! -s "$stdout_file" ] && [ ! -s "$stderr_file" ] &&
        [ "$PWD" = "$before_pwd" ] && [ "$IFS" = "$before_ifs" ] &&
        [ "$(umask)" = "$before_umask" ] && [ "$-" = "$before_options" ] &&
        [ "$(set +o)" = "$before_option_state" ] && [ "$(trap -p)" = "$before_traps" ] &&
        [ "$after_tree" = "$before_tree" ]
)

fixture="${TEST_ROOT}/oversized fixture"
mkdir -p "$fixture/bin" "$fixture/lib"
awk 'BEGIN { for (line = 1; line <= 251; line++) print "# fixture" }' > "$fixture/bin/dotfiles"
awk 'BEGIN { for (line = 1; line <= 501; line++) print "# fixture" }' > "$fixture/lib/example.sh"
output=$(check_production_line_budgets "$fixture" 2>&1)
status=$?
expected='error: production shell line budget exceeded: bin/dotfiles has 251 lines (allowed 250)
error: production shell line budget exceeded: lib/example.sh has 501 lines (allowed 500)'
STATUS=$status
OUTPUT=$output
check_status 'synthetic oversized production files fail the line guard' 1
check_equal 'line-budget diagnostics are relative and measured' "$output" "$expected"

loader_fixture="${TEST_ROOT}/duplicate loader"
mkdir -p "$loader_fixture"
cp -R "${PROJECT_ROOT}/lib" "$loader_fixture/lib"
printf '%s\n' 'source "$DOTFILES_CLI_LOADER_DIR/cli/common.sh"' >> "$loader_fixture/lib/cli.sh"
output=$(check_fixed_loaders "$loader_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'duplicate fixed-loader membership is rejected' 1
check_equal 'duplicate loader diagnostic names only the relative facade' "$output" \
    'error: fixed CLI loader order or membership is invalid: lib/cli.sh'

missing_loader_fixture="${TEST_ROOT}/missing loader leaf"
mkdir -p "$missing_loader_fixture"
cp -R "${PROJECT_ROOT}/lib" "$missing_loader_fixture/lib"
rm -f "$missing_loader_fixture/lib/cli/catalog.sh"
output=$(check_fixed_loaders "$missing_loader_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'missing fixed-loader membership is rejected' 1
check_equal 'missing loader diagnostic identifies only the relative leaf' "$output" \
    'error: fixed CLI loader leaf is missing: lib/cli/catalog.sh'

dynamic_loader_fixture="${TEST_ROOT}/dynamic loader"
mkdir -p "$dynamic_loader_fixture"
cp -R "${PROJECT_ROOT}/lib" "$dynamic_loader_fixture/lib"
printf '%s\n' 'eval '\''source "$DOTFILES_CLI_LOADER_DIR/cli/common.sh"'\''' >> \
    "$dynamic_loader_fixture/lib/cli.sh"
output=$(check_fixed_loaders "$dynamic_loader_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'dynamic loader evaluation is rejected' 1
check_equal 'dynamic loader diagnostic identifies only the relative facade' "$output" \
    'error: dynamic CLI loader syntax is prohibited: lib/cli.sh'

leaf_source_fixture="${TEST_ROOT}/leaf source edge"
mkdir -p "$leaf_source_fixture"
cp -R "${PROJECT_ROOT}/lib" "$leaf_source_fixture/lib"
printf '%s\n' 'source "$DOTFILES_CLI_LOADER_DIR/cli/common.sh"' >> \
    "$leaf_source_fixture/lib/cli/catalog.sh"
output=$(check_fixed_loaders "$leaf_source_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'leaf-to-leaf source edges are rejected' 1
check_equal 'leaf source-edge diagnostic identifies only the relative leaf' "$output" \
    'error: CLI loader leaf contains a facade or sibling source edge: lib/cli/catalog.sh'

duplicate_fixture="${TEST_ROOT}/duplicate function"
mkdir -p "$duplicate_fixture/bin" "$duplicate_fixture/lib"
printf '%s\n' 'same_owner() {' '    :' '}' > "$duplicate_fixture/bin/dotfiles"
printf '%s\n' 'same_owner() {' '    :' '}' > "$duplicate_fixture/lib/example.sh"
output=$(check_duplicate_function_definitions "$duplicate_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'duplicate production function definitions are rejected' 1
check_equal 'duplicate function diagnostic identifies both relative owners' "$output" \
    'error: duplicate production function same_owner: bin/dotfiles,lib/example.sh'

run_command bash "${PROJECT_ROOT}/scripts/check-maintainability.sh"
check_status 'final production tree passes the complete maintainability guard' 0
check_equal 'successful maintainability guard is silent' "$OUTPUT" ''

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
    printf '%s\n' "${PROJECT_ROOT}/bin/dotfiles"
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

if [ "$failures" -ne 0 ]; then
    printf '%s maintainability checks, %s failures\n' "$checks" "$failures"
    exit 1
fi

printf '%s maintainability checks passed\n' "$checks"
