#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
CLI="${PROJECT_ROOT}/bin/dotfiles"
TEST_PARENT=${TMPDIR:-/tmp}
TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-config-state-tests.XXXXXX")

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

# shellcheck source=../bin/dotfiles
source "$CLI"
# shellcheck source=../lib/config-state.sh
source "${PROJECT_ROOT}/lib/config-state.sh"

REAL_CHEZMOI=$(command -v chezmoi)
PROBE_BIN="${TEST_ROOT}/probe-bin"
PROBE_LOG="${TEST_ROOT}/external-invocations.log"
CHEZMOI_LOG="${TEST_ROOT}/chezmoi-invocations.log"
CHEZMOI_PROBE="${TEST_ROOT}/chezmoi-probe"
mkdir -p "$PROBE_BIN"

for probe in brew mise apt apt-get dnf yum pacman apk installer zsh starship less more bat delta diff code vim vi nano open xdg-open op bw pass gopass keepassxc-cli vault sudo doas curl wget git age; do
    printf '%s\n' \
        '#!/bin/sh' \
        'printf "%s\n" "$0 $*" >> "$DOTFILES_CONFIG_PROBE_LOG"' \
        'exit 97' > "${PROBE_BIN}/${probe}"
    chmod +x "${PROBE_BIN}/${probe}"
done

printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "$DOTFILES_CONFIG_CHEZMOI_LOG"' \
    'case " $* " in' \
    '  *" execute-template "*) exec "$DOTFILES_CONFIG_REAL_CHEZMOI" "$@" ;;' \
    '  *) exit 97 ;;' \
    'esac' > "$CHEZMOI_PROBE"
chmod +x "$CHEZMOI_PROBE"

export DOTFILES_CONFIG_PROBE_LOG=$PROBE_LOG
export DOTFILES_CONFIG_CHEZMOI_LOG=$CHEZMOI_LOG
export DOTFILES_CONFIG_REAL_CHEZMOI=$REAL_CHEZMOI
export DOTFILES_CHEZMOI_BIN=$CHEZMOI_PROBE
export DOTFILES_CONFIG_TEST_SKIP_SYNC=1
export PATH="${PROBE_BIN}:/usr/bin:/bin"

SOURCE_DIR=$PROJECT_ROOT
CHEZMOI_BIN=$CHEZMOI_PROBE

failures=0
checks=0
OUTPUT=
STDOUT=
STDERR=
STATUS=0

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

run_command() {
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    "$@" > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
}

run_state() {
    local root=$1
    local profile=$2
    local modules=$3
    local additional=$4
    local platform=$5
    run_command dotfiles_config_state_set_internal "$root" "$profile" "$modules" "$additional" "$platform"
}

check_status() {
    local name=$1
    local expected=$2
    if [ "$STATUS" -eq "$expected" ]; then
        pass "$name"
    else
        fail "$name"
    fi
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

check_not_equal() {
    local name=$1
    local actual=$2
    local unexpected=$3
    if [ "$actual" != "$unexpected" ]; then
        pass "$name"
    else
        STATUS=1
        OUTPUT="unexpected equal value: ${unexpected}"
        fail "$name"
    fi
}

check_contains() {
    local name=$1
    local text=$2
    case "$OUTPUT" in
        *"$text"*) pass "$name" ;;
        *) STATUS=1; fail "$name" ;;
    esac
}

check_not_contains() {
    local name=$1
    local text=$2
    case "$OUTPUT" in
        *"$text"*) STATUS=1; fail "$name" ;;
        *) pass "$name" ;;
    esac
}

check_file_exact() {
    local name=$1
    local file=$2
    local expected=$3
    local expected_file="${TEST_ROOT}/expected"
    printf '%s\n' "$expected" > "$expected_file"
    if cmp -s "$file" "$expected_file"; then
        pass "$name"
    else
        STATUS=1
        OUTPUT="file bytes differ"
        fail "$name"
    fi
}

mode_of() {
    dotfiles_config_stat_mode "$1"
}

identity_of() {
    dotfiles_config_stat_identity "$1"
}

tree_snapshot() {
    (
        CDPATH= cd -- "$1" || exit 1
        find . -print | LC_ALL=C sort
        find . -type f -exec cksum {} \; | LC_ALL=C sort
        find . -type l -print -exec readlink {} \; | LC_ALL=C sort
    )
}

reset_hooks() {
    unset DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE
    unset DOTFILES_CONFIG_TEST_LOCK_IDENTITY_CAPTURE
    unset DOTFILES_CONFIG_TEST_LOCK_IDENTITY_VALIDATION
    unset DOTFILES_CONFIG_TEST_AFTER_LOCK
    unset DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE
    unset DOTFILES_CONFIG_TEST_FILE_FLUSH
    unset DOTFILES_CONFIG_TEST_AFTER_FINAL_CHECK
    unset DOTFILES_CONFIG_TEST_BEFORE_RENAME
    unset DOTFILES_CONFIG_TEST_AFTER_RENAME
    unset DOTFILES_CONFIG_TEST_DIRECTORY_FLUSH
    unset DOTFILES_CONFIG_TEST_AFTER_DIRECTORY_FLUSH
}

assert_no_owned_debris() {
    local name=$1
    local directory=$2
    local debris=
    if [ -d "$directory" ]; then
        debris=$(find "$directory" -maxdepth 1 \( -name '.active-selection.*' -o -name 'active-selection.lock' \) -print)
    fi
    if [ -z "$debris" ]; then
        pass "$name"
    else
        STATUS=1
        OUTPUT="temporary material remains"
        fail "$name"
    fi
}

assert_no_private_files() {
    local name=$1
    local directory=$2
    local debris=
    if [ -d "$directory" ]; then
        debris=$(find "$directory" -maxdepth 1 -name '.active-selection.*' -print)
    fi
    if [ -z "$debris" ]; then
        pass "$name"
    else
        STATUS=1
        OUTPUT="private temporary material remains"
        fail "$name"
    fi
}

write_state() {
    local root=$1
    local body=$2
    mkdir -p "$root/dotfiles"
    chmod 700 "$root/dotfiles"
    printf '%s' "$body" > "$root/dotfiles/active-selection.toml"
    chmod 600 "$root/dotfiles/active-selection.toml"
}

PROFILE_BODY='schema = 1

[selection]
profile = "shell.minimal"
additional_modules = []'

MODULE_BODY='schema = 1

[selection]
modules = ["prompt.starship", "shell.zsh"]
additional_modules = ["shell.zsh.autosuggestions"]'

ALTERNATE_BODY='schema = 1

[selection]
modules = ["prompt.starship"]
additional_modules = []'

EXTERNAL_CONFLICT_BODY='schema = 1

[selection]
modules = ["shell.zsh"]
additional_modules = []'

run_command "$CLI" help
check_status "help succeeds" 0
check_contains "help lists config set" 'dotfiles config set (--profile <profile-id> | --modules <id,id>)'
check_not_contains "help omits interactive config" 'config interactive'
check_not_contains "help omits inspect" 'config inspect'
check_not_contains "help omits doctor" 'config doctor'
check_not_contains "help omits cache reset" 'cache reset'

run_command "$CLI" config
check_status "config requires a subcommand" 2
run_command "$CLI" config unknown
check_status "unknown config subcommand is usage error" 2
run_command "$CLI" config set
check_status "config set requires a base" 2
run_command "$CLI" config set --profile shell.minimal --modules shell.zsh
check_status "both bases are a usage error" 2
run_command "$CLI" config set --modules ''
check_status "empty module base is a usage error" 2
run_command "$CLI" config set --profile
check_status "missing profile value is a usage error" 2
run_command "$CLI" config set --profile --platform debian
check_status "option-shaped profile value is missing" 2
run_command "$CLI" config set --profile shell.minimal --profile shell.minimal
check_status "repeated profile is a usage error" 2
run_command "$CLI" config set --modules shell.zsh --modules prompt.starship
check_status "repeated modules are a usage error" 2
run_command "$CLI" config set --profile shell.minimal --add prompt.starship --add shell.zsh
check_status "repeated additions are a usage error" 2
run_command "$CLI" config set --profile shell.minimal --platform debian --platform macos
check_status "repeated platform is a usage error" 2
run_command "$CLI" config set --profile shell.minimal --unknown
check_status "unknown config set flag is a usage error" 2
run_command "$CLI" config set --profile shell.minimal positional
check_status "positional config set argument is a usage error" 2
run_command "$CLI" config set --profile shell.minimal --yes
check_status "config set exposes no approval flag" 2
run_command "$CLI" config set --help
check_status "config set help succeeds without a base" 0

PROFILE_ROOT="${TEST_ROOT}/profile-state"
PROFILE_HOME="${TEST_ROOT}/profile-home"
mkdir "$PROFILE_HOME"
printf 'private-home-sentinel\n' > "$PROFILE_HOME/sentinel"
HOME_BEFORE=$(tree_snapshot "$PROFILE_HOME")
expected_profile_output='Proposed local selection:
Base: profile shell.minimal
Additional modules: none
Resolved modules for debian:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship
Local selection saved.
Managed home configuration: unchanged.'
run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform debian
check_status "profile selection saves on Debian" 0
check_equal "saved profile summary is exact" "$STDOUT" "$expected_profile_output"
check_equal "saved profile writes no stderr" "$STDERR" ""
check_file_exact "profile state uses exact canonical bytes" "$PROFILE_ROOT/dotfiles/active-selection.toml" "$PROFILE_BODY"
check_equal "dedicated directory mode is 0700" "$(mode_of "$PROFILE_ROOT/dotfiles")" 700
check_equal "state file mode is 0600" "$(mode_of "$PROFILE_ROOT/dotfiles/active-selection.toml")" 600
check_equal "managed HOME is unchanged" "$(tree_snapshot "$PROFILE_HOME")" "$HOME_BEFORE"

PROFILE_IDENTITY=$(identity_of "$PROFILE_ROOT/dotfiles/active-selection.toml")
PROFILE_MODE=$(mode_of "$PROFILE_ROOT/dotfiles/active-selection.toml")
PROFILE_CKSUM=$(cksum "$PROFILE_ROOT/dotfiles/active-selection.toml")
run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform debian
check_status "identical profile state succeeds" 0
check_contains "identical profile state reports unchanged" 'Local selection unchanged.'
check_equal "no-change preserves state identity" "$(identity_of "$PROFILE_ROOT/dotfiles/active-selection.toml")" "$PROFILE_IDENTITY"
check_equal "no-change preserves state mode" "$(mode_of "$PROFILE_ROOT/dotfiles/active-selection.toml")" "$PROFILE_MODE"
check_equal "no-change preserves state bytes" "$(cksum "$PROFILE_ROOT/dotfiles/active-selection.toml")" "$PROFILE_CKSUM"

MODULE_ROOT="${TEST_ROOT}/module-state"
run_command env XDG_CONFIG_HOME="$MODULE_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules prompt.starship,shell.zsh --add shell.zsh.autosuggestions --platform macos
check_status "explicit module selection saves on macOS" 0
check_contains "module summary preserves requested base order" 'Base: modules prompt.starship,shell.zsh'
check_contains "module summary preserves addition order" 'Additional modules: shell.zsh.autosuggestions'
check_file_exact "module state preserves explicit intent without dependency expansion" "$MODULE_ROOT/dotfiles/active-selection.toml" "$MODULE_BODY"

PUBLIC_HOOK_ROOT="${TEST_ROOT}/public-hook-isolation"
run_command env XDG_CONFIG_HOME="$PUBLIC_HOOK_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" \
    DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE=unavailable_private_hook \
    DOTFILES_CONFIG_TEST_LOCK_IDENTITY_CAPTURE=unavailable_private_hook \
    DOTFILES_CONFIG_TEST_LOCK_IDENTITY_VALIDATION=unavailable_private_hook \
    "$CLI" config set --modules prompt.starship --platform debian
check_status "public config set cannot reach private lock failure seams" 0
check_file_exact "public hook isolation still saves canonical state" "$PUBLIC_HOOK_ROOT/dotfiles/active-selection.toml" "$ALTERNATE_BODY"
assert_no_owned_debris "public hook isolation leaves no owned debris" "$PUBLIC_HOOK_ROOT/dotfiles"

OVERLAP_ROOT="${TEST_ROOT}/profile-overlap"
run_command env XDG_CONFIG_HOME="$OVERLAP_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --profile shell.minimal --add shell.zsh --platform debian
check_status "profile and dependency overlap remains valid" 0

run_command env XDG_CONFIG_HOME="${TEST_ROOT}/duplicate-base" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.zsh,shell.zsh --platform debian
check_status "duplicate base intent is invalid" 3
run_command env XDG_CONFIG_HOME="${TEST_ROOT}/duplicate-add" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.zsh --add prompt.starship,prompt.starship --platform debian
check_status "duplicate additional intent is invalid" 3
run_command env XDG_CONFIG_HOME="${TEST_ROOT}/duplicate-cross" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.zsh --add shell.zsh --platform debian
check_status "duplicate base and addition intent is invalid" 3
run_command env XDG_CONFIG_HOME="${TEST_ROOT}/unknown-module" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.unknown --platform debian
check_status "unknown proposed module is invalid" 3
run_command env XDG_CONFIG_HOME="${TEST_ROOT}/unsupported-module" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules terminal.ghostty --platform debian
check_status "unsupported proposed module is invalid" 3

stage_fixture() {
    local name=$1
    local target="${TEST_ROOT}/fixture-${name}/.chezmoidata"
    mkdir -p "$target"
    cp -R "${PROJECT_ROOT}/tests/fixtures/${name}/catalog/." "$target/"
    printf '%s\n' "${TEST_ROOT}/fixture-${name}"
}

VALID_FIXTURE=$(stage_fixture valid)
CYCLE_FIXTURE=$(stage_fixture cycle)
COLLISION_FIXTURE=$(stage_fixture source-collision)
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" XDG_CONFIG_HOME="${TEST_ROOT}/conflict" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules terminal.ghostty,terminal.wezterm --platform macos
check_status "exclusive-group conflict is rejected during save" 3
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" XDG_CONFIG_HOME="${TEST_ROOT}/declared-conflict" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.zsh,terminal.wezterm --platform macos
check_status "declared conflict is rejected during save" 3
run_command env DOTFILES_SOURCE_DIR="$CYCLE_FIXTURE" XDG_CONFIG_HOME="${TEST_ROOT}/cycle" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.alpha --platform debian
check_status "catalog dependency cycle is rejected during save" 3
run_command env DOTFILES_SOURCE_DIR="$COLLISION_FIXTURE" XDG_CONFIG_HOME="${TEST_ROOT}/collision" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.alpha,shell.beta --platform debian
check_status "rendered-target ownership collision is rejected during save" 3

if [ ! -s "$PROBE_LOG" ]; then
    STATUS=0
    OUTPUT=
    pass "saving never invokes prerequisites, artifacts, providers, installers, editors, pagers, networks, or privilege helpers"
else
    STATUS=1
    OUTPUT=$(< "$PROBE_LOG")
    fail "saving never invokes prerequisites, artifacts, providers, installers, editors, pagers, networks, or privilege helpers"
fi
if [ -s "$CHEZMOI_LOG" ] && ! grep -Ev '(^| )execute-template( |$)' "$CHEZMOI_LOG" | grep -q . && \
    ! grep -E '(^| )(apply|diff|init|update|add|remove|purge|destroy|forget|execute|externals|encrypt|decrypt)( |$)' "$CHEZMOI_LOG" | grep -v 'execute-template' | grep -q .; then
    STATUS=0
    OUTPUT=
    pass "saving reaches only Chezmoi catalog template extraction"
else
    STATUS=1
    OUTPUT=$(< "$CHEZMOI_LOG")
    fail "saving reaches only Chezmoi catalog template extraction"
fi

invalid_state_case() {
    local name=$1
    local payload=$2
    local root="${TEST_ROOT}/invalid-${checks}"
    local before
    write_state "$root" "$payload"
    before=$(cksum "$root/dotfiles/active-selection.toml")
    run_state "$root" shell.minimal "" "" debian
    if [ "$STATUS" -eq 3 ] && [ "$(cksum "$root/dotfiles/active-selection.toml")" = "$before" ]; then
        pass "$name"
    else
        fail "$name"
    fi
}

invalid_state_case "malformed current TOML is preserved" 'not toml
'
invalid_state_case "unknown current key is preserved" 'schema = 1

[selection]
profile = "shell.minimal"
unknown = []
additional_modules = []
'
invalid_state_case "unknown current table is preserved" 'schema = 1

[other]
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "wrong current type is preserved" 'schema = 1

[selection]
profile = ["shell.minimal"]
additional_modules = []
'
invalid_state_case "unknown current schema is preserved" 'schema = 2

[selection]
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "duplicate current TOML key is preserved" 'schema = 1

[selection]
profile = "shell.minimal"
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "current comments are non-canonical and preserved" 'schema = 1

[selection]
profile = "shell.minimal"
additional_modules = [] # comment
'
invalid_state_case "alternative current ordering is preserved" 'schema = 1

[selection]
additional_modules = []
profile = "shell.minimal"
'
invalid_state_case "alternative current spacing is preserved" 'schema=1

[selection]
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "extra current blank line is preserved" 'schema = 1


[selection]
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "missing current final newline is preserved" "$PROFILE_BODY"
invalid_state_case "extra current final newline is preserved" "${PROFILE_BODY}

"
invalid_state_case "both current bases are preserved" 'schema = 1

[selection]
profile = "shell.minimal"
modules = ["shell.zsh"]
additional_modules = []
'
invalid_state_case "neither current base is preserved" 'schema = 1

[selection]
additional_modules = []
'
invalid_state_case "empty current module base is preserved" 'schema = 1

[selection]
modules = []
additional_modules = []
'
invalid_state_case "duplicate current explicit intent is preserved" 'schema = 1

[selection]
modules = ["shell.zsh", "shell.zsh"]
additional_modules = []
'
invalid_state_case "cross-list duplicate current intent is preserved" 'schema = 1

[selection]
modules = ["shell.zsh"]
additional_modules = ["shell.zsh"]
'
invalid_state_case "catalog-invalid canonical current state is preserved" 'schema = 1

[selection]
modules = ["shell.unknown"]
additional_modules = []
'

NEW_ROOT="${TEST_ROOT}/one-level-root"
umask 000
run_state "$NEW_ROOT" shell.minimal "" "" debian
umask 022
check_status "private seam creates a one-level root" 0
check_equal "created root ignores permissive umask" "$(mode_of "$NEW_ROOT")" 700
check_equal "created dedicated directory ignores permissive umask" "$(mode_of "$NEW_ROOT/dotfiles")" 700
check_equal "created state ignores permissive umask" "$(mode_of "$NEW_ROOT/dotfiles/active-selection.toml")" 600

DEEP_ROOT="${TEST_ROOT}/missing-parent/missing-root"
run_state "$DEEP_ROOT" shell.minimal "" "" debian
check_status "writer does not recursively invent a root chain" 3
if [ ! -e "${TEST_ROOT}/missing-parent" ]; then STATUS=0; OUTPUT=; pass "failed deep root creates no parent"; else STATUS=1; OUTPUT='parent was created'; fail "failed deep root creates no parent"; fi

REPO_STATE_ROOT="${PROJECT_ROOT}/.forbidden-config-state-test"
run_state "$REPO_STATE_ROOT" shell.minimal "" "" debian
check_status "configuration root inside repository is rejected" 3
if [ ! -e "$REPO_STATE_ROOT" ]; then STATUS=0; OUTPUT=; pass "repository rejection creates no state"; else STATUS=1; OUTPUT='repository path was created'; fail "repository rejection creates no state"; fi

HOME_FALLBACK="${TEST_ROOT}/fallback-home"
mkdir "$HOME_FALLBACK"
run_command env -u XDG_CONFIG_HOME HOME="$HOME_FALLBACK" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform debian
check_status "unset XDG uses HOME fallback" 0
if [ -f "$HOME_FALLBACK/.config/dotfiles/active-selection.toml" ]; then STATUS=0; OUTPUT=; pass "unset XDG writes the literal HOME fallback"; else STATUS=1; OUTPUT='fallback missing'; fail "unset XDG writes the literal HOME fallback"; fi

EMPTY_XDG_HOME="${TEST_ROOT}/empty-xdg-home"
mkdir "$EMPTY_XDG_HOME"
run_command env XDG_CONFIG_HOME= HOME="$EMPTY_XDG_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform macos
check_status "empty XDG uses HOME fallback" 0
if [ -f "$EMPTY_XDG_HOME/.config/dotfiles/active-selection.toml" ]; then STATUS=0; OUTPUT=; pass "empty XDG writes the literal HOME fallback"; else STATUS=1; OUTPUT='fallback missing'; fail "empty XDG writes the literal HOME fallback"; fi

PRECEDENCE_HOME="${TEST_ROOT}/precedence-home"
mkdir "$PRECEDENCE_HOME"
run_command env XDG_CONFIG_HOME=relative HOME="$PRECEDENCE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform debian
check_status "invalid non-empty XDG fails closed" 3
PRECEDENCE_OUTPUT=$OUTPUT
if [ ! -e "$PRECEDENCE_HOME/.config" ]; then STATUS=0; OUTPUT=; pass "invalid XDG never falls back to HOME"; else STATUS=1; OUTPUT='HOME fallback was used'; fail "invalid XDG never falls back to HOME"; fi
OUTPUT=$PRECEDENCE_OUTPUT
check_not_contains "invalid XDG diagnostic hides raw root" 'relative'
check_contains "invalid XDG diagnostic uses origin token" '$XDG_CONFIG_HOME'

for malformed_root in \
    "${TEST_ROOT}//ambiguous" \
    "${TEST_ROOT}/./dot" \
    "${TEST_ROOT}/../escape" \
    "${TEST_ROOT}/with~tilde" \
    "${TEST_ROOT}/with\$variable" \
    "${TEST_ROOT}/with*glob" \
    "${TEST_ROOT}/with;syntax"; do
    run_state "$malformed_root" shell.minimal "" "" debian
    if [ "$STATUS" -eq 3 ] && [[ $OUTPUT != *"$malformed_root"* ]]; then
        pass "malformed literal root fails privately"
    else
        fail "malformed literal root fails privately"
    fi
done

SYMLINK_TARGET="${TEST_ROOT}/symlink-target"
mkdir "$SYMLINK_TARGET"
ln -s "$SYMLINK_TARGET" "${TEST_ROOT}/root-link"
run_state "${TEST_ROOT}/root-link" shell.minimal "" "" debian
check_status "symlink configuration root is rejected" 3

mkdir "${TEST_ROOT}/component-real"
ln -s "${TEST_ROOT}/component-real" "${TEST_ROOT}/component-link"
mkdir "${TEST_ROOT}/component-real/root"
run_state "${TEST_ROOT}/component-link/root" shell.minimal "" "" debian
check_status "symlink path component is rejected" 3

DEDICATED_LINK_ROOT="${TEST_ROOT}/dedicated-link"
mkdir "$DEDICATED_LINK_ROOT" "${TEST_ROOT}/dedicated-target"
ln -s "${TEST_ROOT}/dedicated-target" "$DEDICATED_LINK_ROOT/dotfiles"
run_state "$DEDICATED_LINK_ROOT" shell.minimal "" "" debian
check_status "symlink dedicated directory is rejected" 3

STATE_LINK_ROOT="${TEST_ROOT}/state-link"
mkdir -p "$STATE_LINK_ROOT/dotfiles"
chmod 700 "$STATE_LINK_ROOT/dotfiles"
printf '%s\n' "$PROFILE_BODY" > "${TEST_ROOT}/state-link-target"
chmod 600 "${TEST_ROOT}/state-link-target"
ln -s "${TEST_ROOT}/state-link-target" "$STATE_LINK_ROOT/dotfiles/active-selection.toml"
run_state "$STATE_LINK_ROOT" shell.minimal "" "" debian
check_status "symlink state file is rejected" 3

MODE_ROOT="${TEST_ROOT}/unsafe-directory-mode"
mkdir -p "$MODE_ROOT/dotfiles"
chmod 755 "$MODE_ROOT/dotfiles"
run_state "$MODE_ROOT" shell.minimal "" "" debian
check_status "group-readable dedicated directory is rejected" 3
check_equal "unsafe dedicated mode is not repaired" "$(mode_of "$MODE_ROOT/dotfiles")" 755

FILE_MODE_ROOT="${TEST_ROOT}/unsafe-file-mode"
write_state "$FILE_MODE_ROOT" "${PROFILE_BODY}"$'\n'
chmod 644 "$FILE_MODE_ROOT/dotfiles/active-selection.toml"
run_state "$FILE_MODE_ROOT" shell.minimal "" "" debian
check_status "group-readable state file is rejected" 3
check_equal "unsafe state mode is not repaired" "$(mode_of "$FILE_MODE_ROOT/dotfiles/active-selection.toml")" 644

WRONG_DIRECTORY_ROOT="${TEST_ROOT}/wrong-directory-type"
mkdir "$WRONG_DIRECTORY_ROOT"
printf 'not a directory\n' > "$WRONG_DIRECTORY_ROOT/dotfiles"
run_state "$WRONG_DIRECTORY_ROOT" shell.minimal "" "" debian
check_status "wrong dedicated-directory type is rejected" 3

WRONG_STATE_ROOT="${TEST_ROOT}/wrong-state-type"
mkdir -p "$WRONG_STATE_ROOT/dotfiles/active-selection.toml"
chmod 700 "$WRONG_STATE_ROOT/dotfiles"
run_state "$WRONG_STATE_ROOT" shell.minimal "" "" debian
check_status "wrong state-file type is rejected" 3

UNWRITABLE_ROOT="${TEST_ROOT}/unwritable"
mkdir -p "$UNWRITABLE_ROOT/dotfiles"
chmod 700 "$UNWRITABLE_ROOT/dotfiles"
chmod 500 "$UNWRITABLE_ROOT"
run_state "$UNWRITABLE_ROOT" shell.minimal "" "" debian
check_status "unwritable mutation root is rejected" 3
chmod 700 "$UNWRITABLE_ROOT"

SYSTEM_ROOT=
for candidate in /private/tmp /var/tmp /tmp; do
    if [ -d "$candidate" ] && [ ! -L "$candidate" ] && [ "$(dotfiles_config_stat_owner "$candidate")" != "$(id -u)" ]; then
        SYSTEM_ROOT=$candidate
        break
    fi
done
if [ -n "$SYSTEM_ROOT" ]; then
    run_state "$SYSTEM_ROOT" shell.minimal "" "" debian
    check_status "ownership mismatch is rejected" 3
else
    STATUS=0
    OUTPUT=
    pass "ownership mismatch fixture unavailable for this user"
fi

LOCK_ROOT="${TEST_ROOT}/active-lock"
mkdir -p "$LOCK_ROOT/dotfiles/active-selection.lock"
chmod 700 "$LOCK_ROOT/dotfiles" "$LOCK_ROOT/dotfiles/active-selection.lock"
printf 'pre-existing lock sentinel\n' > "$LOCK_ROOT/dotfiles/active-selection.lock/sentinel"
LOCK_IDENTITY_BEFORE=$(identity_of "$LOCK_ROOT/dotfiles/active-selection.lock")
LOCK_MODE_BEFORE=$(mode_of "$LOCK_ROOT/dotfiles/active-selection.lock")
LOCK_SENTINEL_BEFORE=$(cksum < "$LOCK_ROOT/dotfiles/active-selection.lock/sentinel")
run_state "$LOCK_ROOT" shell.minimal "" "" debian
check_status "active or stale writer lock is refused" 3
check_equal "pre-existing lock identity is unchanged" "$(identity_of "$LOCK_ROOT/dotfiles/active-selection.lock")" "$LOCK_IDENTITY_BEFORE"
check_equal "pre-existing lock mode is unchanged" "$(mode_of "$LOCK_ROOT/dotfiles/active-selection.lock")" "$LOCK_MODE_BEFORE"
check_equal "pre-existing lock contents are unchanged" "$(cksum < "$LOCK_ROOT/dotfiles/active-selection.lock/sentinel")" "$LOCK_SENTINEL_BEFORE"

LOCK_FILE_ROOT="${TEST_ROOT}/lock-file"
mkdir -p "$LOCK_FILE_ROOT/dotfiles"
chmod 700 "$LOCK_FILE_ROOT/dotfiles"
printf 'unowned lock object\n' > "$LOCK_FILE_ROOT/dotfiles/active-selection.lock"
chmod 600 "$LOCK_FILE_ROOT/dotfiles/active-selection.lock"
LOCK_FILE_IDENTITY=$(identity_of "$LOCK_FILE_ROOT/dotfiles/active-selection.lock")
LOCK_FILE_CHECKSUM=$(cksum < "$LOCK_FILE_ROOT/dotfiles/active-selection.lock")
run_state "$LOCK_FILE_ROOT" shell.minimal "" "" debian
check_status "pre-existing non-directory lock is refused" 3
check_equal "pre-existing non-directory lock identity is unchanged" "$(identity_of "$LOCK_FILE_ROOT/dotfiles/active-selection.lock")" "$LOCK_FILE_IDENTITY"
check_equal "pre-existing non-directory lock bytes are unchanged" "$(cksum < "$LOCK_FILE_ROOT/dotfiles/active-selection.lock")" "$LOCK_FILE_CHECKSUM"

LOCK_LINK_ROOT="${TEST_ROOT}/lock-link"
mkdir -p "$LOCK_LINK_ROOT/dotfiles" "${TEST_ROOT}/lock-link-target"
chmod 700 "$LOCK_LINK_ROOT/dotfiles" "${TEST_ROOT}/lock-link-target"
ln -s "${TEST_ROOT}/lock-link-target" "$LOCK_LINK_ROOT/dotfiles/active-selection.lock"
run_state "$LOCK_LINK_ROOT" shell.minimal "" "" debian
check_status "symlink writer lock is refused" 3
if [ -L "$LOCK_LINK_ROOT/dotfiles/active-selection.lock" ]; then STATUS=0; OUTPUT=; pass "writer never follows or removes a symlink lock"; else STATUS=1; OUTPUT='lock link changed'; fail "writer never follows or removes a symlink lock"; fi

hook_fail() { return 1; }
hook_record_lock_mode_and_fail() {
    mode_of "$DOTFILES_CONFIG_LOCK_PATH" > "$DOTFILES_CONFIG_TEST_LOCK_MODE_FILE"
    return 1
}
hook_make_lock_mode_unsafe() {
    chmod 755 "$DOTFILES_CONFIG_LOCK_PATH"
}
hook_replace_lock_with_symlink() {
    rmdir "$DOTFILES_CONFIG_LOCK_PATH"
    ln -s "$DOTFILES_CONFIG_TEST_LOCK_REPLACEMENT_TARGET" "$DOTFILES_CONFIG_LOCK_PATH"
}
hook_replace_lock_with_directory() {
    rmdir "$DOTFILES_CONFIG_LOCK_PATH"
    mkdir "$DOTFILES_CONFIG_LOCK_PATH"
    chmod 700 "$DOTFILES_CONFIG_LOCK_PATH"
    identity_of "$DOTFILES_CONFIG_LOCK_PATH" > "$DOTFILES_CONFIG_TEST_LOCK_REPLACEMENT_IDENTITY_FILE"
}
hook_external_drift() {
    printf 'external writer bytes\n' > "$DOTFILES_CONFIG_STATE_PATH"
    chmod 600 "$DOTFILES_CONFIG_STATE_PATH"
}
hook_external_final_window() {
    local conflict_path="${DOTFILES_CONFIG_DIRECTORY}/.external-conflict"
    printf '%s\n' "$EXTERNAL_CONFLICT_BODY" > "$conflict_path"
    chmod 600 "$conflict_path"
    mv -f "$conflict_path" "$DOTFILES_CONFIG_STATE_PATH"
    identity_of "$DOTFILES_CONFIG_STATE_PATH" > "$DOTFILES_CONFIG_TEST_FINAL_WINDOW_IDENTITY_FILE"
    cksum < "$DOTFILES_CONFIG_STATE_PATH" > "$DOTFILES_CONFIG_TEST_FINAL_WINDOW_CHECKSUM_FILE"
}
hook_post_rename_drift() {
    printf '%s\n' "$PROFILE_BODY" > "$DOTFILES_CONFIG_STATE_PATH"
    chmod 600 "$DOTFILES_CONFIG_STATE_PATH"
}
hook_replace_temp_with_symlink() {
    local target="${TEST_ROOT}/temp-link-target"
    printf 'external target sentinel\n' > "$target"
    rm -f "$DOTFILES_CONFIG_TEMP_PATH"
    ln -s "$target" "$DOTFILES_CONFIG_TEMP_PATH"
}
hook_hup() { dotfiles_config_handle_signal 129; }
hook_int() { dotfiles_config_handle_signal 130; }
hook_term() { dotfiles_config_handle_signal 143; }

lock_failure_case() {
    local name=$1
    local hook_variable=$2
    local hook_function=${3:-hook_fail}
    local root="${TEST_ROOT}/lock-failure-${checks}"
    local before
    reset_hooks
    write_state "$root" "${PROFILE_BODY}"$'\n'
    before=$(cksum < "$root/dotfiles/active-selection.toml")
    printf -v "$hook_variable" '%s' "$hook_function"
    run_state "$root" "" prompt.starship "" debian
    if [ "$STATUS" -eq 4 ] && [ "$(cksum < "$root/dotfiles/active-selection.toml")" = "$before" ]; then
        pass "$name"
    else
        fail "$name"
    fi
    assert_no_owned_debris "${name} cleans the exact owned lock" "$root/dotfiles"
    check_not_contains "${name} hides the raw configuration root" "$root"
    check_not_contains "${name} hides the username" "$(id -un)"
    check_not_contains "${name} hides the hostname" "$(hostname)"
    reset_hooks
}

DOTFILES_CONFIG_TEST_LOCK_MODE_FILE="${TEST_ROOT}/created-lock-mode"
CALLER_UMASK=$(umask)
umask 000
lock_failure_case "failure immediately after lock creation is cleaned" DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE hook_record_lock_mode_and_fail
umask "$CALLER_UMASK"
check_equal "lock creation ignores a permissive caller umask" "$(< "$DOTFILES_CONFIG_TEST_LOCK_MODE_FILE")" 700
lock_failure_case "identity capture failure is cleaned through exact lock authority" DOTFILES_CONFIG_TEST_LOCK_IDENTITY_CAPTURE
lock_failure_case "identity validation failure cleans the registered lock" DOTFILES_CONFIG_TEST_LOCK_IDENTITY_VALIDATION
lock_failure_case "validation failure after registration cleans the owned lock" DOTFILES_CONFIG_TEST_AFTER_LOCK
lock_failure_case "permission validation failure cleans the exact owned lock" DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE hook_make_lock_mode_unsafe

LOCK_SETUP_SIGNAL_ROOT="${TEST_ROOT}/lock-setup-signal"
write_state "$LOCK_SETUP_SIGNAL_ROOT" "${PROFILE_BODY}"$'\n'
LOCK_SETUP_SIGNAL_BEFORE=$(cksum < "$LOCK_SETUP_SIGNAL_ROOT/dotfiles/active-selection.toml")
DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE=hook_hup
run_state "$LOCK_SETUP_SIGNAL_ROOT" "" prompt.starship "" debian
check_status "HUP during lock setup returns 129" 129
check_equal "HUP during lock setup preserves prior state" "$(cksum < "$LOCK_SETUP_SIGNAL_ROOT/dotfiles/active-selection.toml")" "$LOCK_SETUP_SIGNAL_BEFORE"
assert_no_owned_debris "HUP during lock setup cleans the exact owned lock" "$LOCK_SETUP_SIGNAL_ROOT/dotfiles"
reset_hooks

LOCK_REPLACEMENT_TARGET="${TEST_ROOT}/lock-replacement-target"
mkdir "$LOCK_REPLACEMENT_TARGET"
chmod 700 "$LOCK_REPLACEMENT_TARGET"
DOTFILES_CONFIG_TEST_LOCK_REPLACEMENT_TARGET=$LOCK_REPLACEMENT_TARGET
LOCK_REPLACED_LINK_ROOT="${TEST_ROOT}/lock-replaced-link"
write_state "$LOCK_REPLACED_LINK_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE=hook_replace_lock_with_symlink
run_state "$LOCK_REPLACED_LINK_ROOT" "" prompt.starship "" debian
check_status "symlink replacement during lock setup fails safely" 4
if [ -L "$LOCK_REPLACED_LINK_ROOT/dotfiles/active-selection.lock" ]; then STATUS=0; OUTPUT=; pass "cleanup leaves a symlink replacement untouched"; else STATUS=1; OUTPUT='symlink replacement changed'; fail "cleanup leaves a symlink replacement untouched"; fi
check_equal "cleanup never follows the symlink replacement" "$(identity_of "$LOCK_REPLACEMENT_TARGET")" "$(identity_of "$(readlink "$LOCK_REPLACED_LINK_ROOT/dotfiles/active-selection.lock")")"
assert_no_private_files "symlink replacement failure leaves no private files" "$LOCK_REPLACED_LINK_ROOT/dotfiles"
reset_hooks

LOCK_REPLACED_DIRECTORY_ROOT="${TEST_ROOT}/lock-replaced-directory"
LOCK_REPLACEMENT_IDENTITY_FILE="${TEST_ROOT}/lock-replacement-identity"
DOTFILES_CONFIG_TEST_LOCK_REPLACEMENT_IDENTITY_FILE=$LOCK_REPLACEMENT_IDENTITY_FILE
write_state "$LOCK_REPLACED_DIRECTORY_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE=hook_replace_lock_with_directory
run_state "$LOCK_REPLACED_DIRECTORY_ROOT" "" prompt.starship "" debian
check_status "different-directory replacement during lock setup fails safely" 4
check_equal "cleanup preserves the different lock identity" "$(identity_of "$LOCK_REPLACED_DIRECTORY_ROOT/dotfiles/active-selection.lock")" "$(< "$LOCK_REPLACEMENT_IDENTITY_FILE")"
assert_no_private_files "different-directory replacement leaves no private files" "$LOCK_REPLACED_DIRECTORY_ROOT/dotfiles"
reset_hooks

failure_case() {
    local name=$1
    local hook_variable=$2
    local root="${TEST_ROOT}/failure-${checks}"
    local before
    reset_hooks
    write_state "$root" "${PROFILE_BODY}"$'\n'
    before=$(cksum "$root/dotfiles/active-selection.toml")
    printf -v "$hook_variable" '%s' hook_fail
    run_state "$root" "" prompt.starship "" debian
    if [ "$STATUS" -eq 4 ] && [ "$(cksum "$root/dotfiles/active-selection.toml")" = "$before" ]; then
        pass "$name"
    else
        fail "$name"
    fi
    assert_no_owned_debris "${name} cleans owned temporary material" "$root/dotfiles"
    reset_hooks
}

failure_case "temporary-write failure preserves prior state" DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE
failure_case "file-flush failure preserves prior state" DOTFILES_CONFIG_TEST_FILE_FLUSH
failure_case "rename failure preserves prior state" DOTFILES_CONFIG_TEST_BEFORE_RENAME

TEMP_LINK_ROOT="${TEST_ROOT}/temp-link"
write_state "$TEMP_LINK_ROOT" "${PROFILE_BODY}"$'\n'
TEMP_LINK_BEFORE=$(cksum "$TEMP_LINK_ROOT/dotfiles/active-selection.toml")
DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE=hook_replace_temp_with_symlink
run_state "$TEMP_LINK_ROOT" "" prompt.starship "" debian
check_status "symlink replacement of the private temporary file is rejected" 3
check_equal "temporary symlink replacement preserves prior state" "$(cksum "$TEMP_LINK_ROOT/dotfiles/active-selection.toml")" "$TEMP_LINK_BEFORE"
check_equal "temporary symlink replacement never writes its target" "$(< "${TEST_ROOT}/temp-link-target")" 'external target sentinel'
if find "$TEMP_LINK_ROOT/dotfiles" -maxdepth 1 -type l -name '.active-selection.tmp.*' -print -quit | grep -q .; then STATUS=0; OUTPUT=; pass "cleanup does not remove an externally replaced temporary path"; else STATUS=1; OUTPUT='external replacement was removed'; fail "cleanup does not remove an externally replaced temporary path"; fi
reset_hooks

POST_VALIDATE_ROOT="${TEST_ROOT}/post-validation-failure"
write_state "$POST_VALIDATE_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_RENAME=hook_fail
run_state "$POST_VALIDATE_ROOT" "" prompt.starship "" debian
check_status "post-rename validation failure is uncertain" 4
check_contains "post-validation uncertainty recommends doctor" 'Run dotfiles config doctor'
assert_no_owned_debris "post-validation failure cleans owned temporary material" "$POST_VALIDATE_ROOT/dotfiles"
reset_hooks

DIRECTORY_FLUSH_ROOT="${TEST_ROOT}/directory-flush-failure"
write_state "$DIRECTORY_FLUSH_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_DIRECTORY_FLUSH=hook_fail
run_state "$DIRECTORY_FLUSH_ROOT" "" prompt.starship "" debian
check_status "directory-flush failure is uncertain" 4
check_contains "directory-flush uncertainty recommends doctor" 'Run dotfiles config doctor'
assert_no_owned_debris "directory-flush failure cleans owned temporary material" "$DIRECTORY_FLUSH_ROOT/dotfiles"
reset_hooks

DRIFT_ROOT="${TEST_ROOT}/pre-rename-drift"
write_state "$DRIFT_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE=hook_external_drift
run_state "$DRIFT_ROOT" "" prompt.starship "" debian
check_status "observed external drift before rename returns status 3" 3
check_equal "observed pre-rename drift preserves external bytes" "$(< "$DRIFT_ROOT/dotfiles/active-selection.toml")" 'external writer bytes'
assert_no_owned_debris "pre-rename drift cleans owned temporary material" "$DRIFT_ROOT/dotfiles"
reset_hooks

POST_DRIFT_ROOT="${TEST_ROOT}/post-rename-drift"
write_state "$POST_DRIFT_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_RENAME=hook_post_rename_drift
run_state "$POST_DRIFT_ROOT" "" prompt.starship "" debian
check_status "post-rename drift returns uncertain status 4" 4
check_file_exact "post-rename drift is not rolled back" "$POST_DRIFT_ROOT/dotfiles/active-selection.toml" "$PROFILE_BODY"
check_contains "post-rename drift recommends doctor" 'Run dotfiles config doctor'
reset_hooks

FINAL_WINDOW_ROOT="${TEST_ROOT}/final-window"
write_state "$FINAL_WINDOW_ROOT" "${PROFILE_BODY}"$'\n'
FINAL_WINDOW_PRIOR_IDENTITY=$(identity_of "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml")
FINAL_WINDOW_PRIOR_CHECKSUM=$(cksum < "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml")
FINAL_WINDOW_PROPOSED_FILE="${TEST_ROOT}/final-window-proposed"
FINAL_WINDOW_CONFLICT_FILE="${TEST_ROOT}/final-window-conflict"
printf '%s\n' "$ALTERNATE_BODY" > "$FINAL_WINDOW_PROPOSED_FILE"
printf '%s\n' "$EXTERNAL_CONFLICT_BODY" > "$FINAL_WINDOW_CONFLICT_FILE"
FINAL_WINDOW_PROPOSED_CHECKSUM=$(cksum < "$FINAL_WINDOW_PROPOSED_FILE")
FINAL_WINDOW_CONFLICT_CHECKSUM=$(cksum < "$FINAL_WINDOW_CONFLICT_FILE")
run_command dotfiles_config_parse_file "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml"
check_status "final-window prior body is canonical schema 1" 0
run_command dotfiles_config_parse_file "$FINAL_WINDOW_PROPOSED_FILE"
check_status "final-window proposed body is canonical schema 1" 0
run_command dotfiles_config_parse_file "$FINAL_WINDOW_CONFLICT_FILE"
check_status "final-window external-conflict body is canonical schema 1" 0
FINAL_WINDOW_EXTERNAL_IDENTITY_FILE="${TEST_ROOT}/final-window-external-identity"
FINAL_WINDOW_EXTERNAL_CHECKSUM_FILE="${TEST_ROOT}/final-window-external-checksum"
DOTFILES_CONFIG_TEST_FINAL_WINDOW_IDENTITY_FILE=$FINAL_WINDOW_EXTERNAL_IDENTITY_FILE
DOTFILES_CONFIG_TEST_FINAL_WINDOW_CHECKSUM_FILE=$FINAL_WINDOW_EXTERNAL_CHECKSUM_FILE
DOTFILES_CONFIG_TEST_AFTER_FINAL_CHECK=hook_external_final_window
run_state "$FINAL_WINDOW_ROOT" "" prompt.starship "" debian
check_status "non-cooperating write in the final check-to-rename window cannot be serialized portably" 0
FINAL_WINDOW_EXTERNAL_IDENTITY=$(< "$FINAL_WINDOW_EXTERNAL_IDENTITY_FILE")
FINAL_WINDOW_EXTERNAL_CHECKSUM=$(< "$FINAL_WINDOW_EXTERNAL_CHECKSUM_FILE")
FINAL_WINDOW_RESULT_IDENTITY=$(identity_of "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml")
FINAL_WINDOW_RESULT_CHECKSUM=$(cksum < "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml")
check_not_equal "final-window prior and external conflict are distinct canonical states" "$FINAL_WINDOW_PRIOR_CHECKSUM" "$FINAL_WINDOW_EXTERNAL_CHECKSUM"
check_not_equal "final-window external conflict differs from the proposal" "$FINAL_WINDOW_EXTERNAL_CHECKSUM" "$FINAL_WINDOW_PROPOSED_CHECKSUM"
check_equal "final-window hook published the complete conflicting canonical document" "$FINAL_WINDOW_EXTERNAL_CHECKSUM" "$FINAL_WINDOW_CONFLICT_CHECKSUM"
check_not_equal "final-window hook replaced the prior destination object" "$FINAL_WINDOW_EXTERNAL_IDENTITY" "$FINAL_WINDOW_PRIOR_IDENTITY"
check_not_equal "ordinary rename displaced the external conflict object" "$FINAL_WINDOW_RESULT_IDENTITY" "$FINAL_WINDOW_EXTERNAL_IDENTITY"
check_file_exact "final-window replacement still publishes one complete canonical document" "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml" "$ALTERNATE_BODY"
check_equal "final-window destination checksum is exactly the proposal" "$FINAL_WINDOW_RESULT_CHECKSUM" "$FINAL_WINDOW_PROPOSED_CHECKSUM"
check_not_equal "final-window destination is not the prior document" "$FINAL_WINDOW_RESULT_CHECKSUM" "$FINAL_WINDOW_PRIOR_CHECKSUM"
check_not_equal "final-window destination is not the external conflict" "$FINAL_WINDOW_RESULT_CHECKSUM" "$FINAL_WINDOW_EXTERNAL_CHECKSUM"
run_command dotfiles_config_parse_file "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml"
check_status "final-window destination strictly parses as canonical schema 1" 0
assert_no_owned_debris "final-window replacement leaves no owned debris" "$FINAL_WINDOW_ROOT/dotfiles"
reset_hooks

SIGNAL_HUP_ROOT="${TEST_ROOT}/signal-hup"
write_state "$SIGNAL_HUP_ROOT" "${PROFILE_BODY}"$'\n'
HUP_BEFORE=$(cksum "$SIGNAL_HUP_ROOT/dotfiles/active-selection.toml")
DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE=hook_hup
run_state "$SIGNAL_HUP_ROOT" "" prompt.starship "" debian
check_status "HUP before rename returns 129" 129
check_equal "HUP before rename preserves prior bytes" "$(cksum "$SIGNAL_HUP_ROOT/dotfiles/active-selection.toml")" "$HUP_BEFORE"
assert_no_owned_debris "HUP cleans owned temporary material" "$SIGNAL_HUP_ROOT/dotfiles"
reset_hooks

SIGNAL_INT_ROOT="${TEST_ROOT}/signal-int"
write_state "$SIGNAL_INT_ROOT" "${PROFILE_BODY}"$'\n'
INT_BEFORE=$(cksum "$SIGNAL_INT_ROOT/dotfiles/active-selection.toml")
DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE=hook_int
run_state "$SIGNAL_INT_ROOT" "" prompt.starship "" debian
check_status "INT before rename returns 130" 130
check_equal "INT before rename preserves prior bytes" "$(cksum "$SIGNAL_INT_ROOT/dotfiles/active-selection.toml")" "$INT_BEFORE"
assert_no_owned_debris "INT cleans owned temporary material" "$SIGNAL_INT_ROOT/dotfiles"
reset_hooks

SIGNAL_TERM_ROOT="${TEST_ROOT}/signal-term-critical"
write_state "$SIGNAL_TERM_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_BEFORE_RENAME=hook_term
run_state "$SIGNAL_TERM_ROOT" "" prompt.starship "" debian
check_status "TERM across the critical region returns 143 after commit handling" 143
check_file_exact "critical TERM leaves one complete committed document" "$SIGNAL_TERM_ROOT/dotfiles/active-selection.toml" "$ALTERNATE_BODY"
assert_no_owned_debris "critical TERM cleans owned temporary material" "$SIGNAL_TERM_ROOT/dotfiles"
reset_hooks

DOTFILES_CONFIG_TEST_RELEASE_FILE="${TEST_ROOT}/release-writer"
hook_hold_lock() {
    local attempt
    for attempt in {1..500}; do
        [ -e "$DOTFILES_CONFIG_TEST_RELEASE_FILE" ] && return 0
        sleep 0.01
    done
    return 1
}

CONCURRENT_ROOT="${TEST_ROOT}/concurrent"
DOTFILES_CONFIG_TEST_AFTER_LOCK=hook_hold_lock
dotfiles_config_state_set_internal "$CONCURRENT_ROOT" shell.minimal "" "" debian > "${TEST_ROOT}/writer-one.out" 2>&1 &
WRITER_ONE_PID=$!
for attempt in {1..500}; do
    [ -d "$CONCURRENT_ROOT/dotfiles/active-selection.lock" ] && break
    sleep 0.01
done
run_state "$CONCURRENT_ROOT" "" prompt.starship "" debian
SECOND_STATUS=$STATUS
SECOND_OUTPUT=$OUTPUT
touch "$DOTFILES_CONFIG_TEST_RELEASE_FILE"
wait "$WRITER_ONE_PID"
FIRST_STATUS=$?
STATUS=$SECOND_STATUS
OUTPUT=$SECOND_OUTPUT
check_equal "a second cooperating writer fails immediately" "$SECOND_STATUS" 3
check_equal "the lock-owning writer completes" "$FIRST_STATUS" 0
check_file_exact "cooperating writers neither merge nor overwrite selections" "$CONCURRENT_ROOT/dotfiles/active-selection.toml" "$PROFILE_BODY"
assert_no_owned_debris "cooperating writer success cleans its lock" "$CONCURRENT_ROOT/dotfiles"
reset_hooks

run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" "$CLI" resolve
check_status "resolve still requires an explicit base after state is saved" 2
run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" "$CLI" prerequisite check
check_status "prerequisite check still requires an explicit base after state is saved" 2
run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" "$CLI" plan
check_status "plan still requires an explicit base after state is saved" 2
run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" "$CLI" apply
check_status "apply still requires an explicit base after state is saved" 2
run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" resolve --modules prompt.starship --platform debian
check_equal "explicit resolve ignores saved selection" "$STDOUT" 'prompt.starship'

PRIVACY_ROOT="${TEST_ROOT}/privacy-root"
write_state "$PRIVACY_ROOT" 'private-state-contents
'
run_state "$PRIVACY_ROOT" shell.minimal "" "" debian
check_status "invalid private state fails" 3
check_not_contains "state diagnostics hide raw configuration root" "$PRIVACY_ROOT"
check_not_contains "state diagnostics hide username" "$(id -un)"
check_not_contains "state diagnostics hide hostname" "$(hostname)"
check_not_contains "state diagnostics hide state contents" 'private-state-contents'
check_contains "state diagnostics use abbreviated origin token" '$XDG_CONFIG_HOME/dotfiles/active-selection.toml'

UNRELATED_ROOT="${TEST_ROOT}/unrelated"
mkdir "$UNRELATED_ROOT"
printf 'unrelated sentinel\n' > "$UNRELATED_ROOT/sentinel"
UNRELATED_BEFORE=$(cksum "$UNRELATED_ROOT/sentinel")
run_state "$UNRELATED_ROOT" shell.minimal "" "" debian
check_status "isolated local save succeeds beside an unrelated file" 0
check_equal "local save leaves unrelated files unchanged" "$(cksum "$UNRELATED_ROOT/sentinel")" "$UNRELATED_BEFORE"
assert_no_owned_debris "successful save leaves no temporary material" "$UNRELATED_ROOT/dotfiles"

if grep -R -E 'schema[[:space:]]*=[[:space:]]*[23]|schema (2|3)' \
    "$PROJECT_ROOT/.chezmoidata" "$PROJECT_ROOT/lib" >/dev/null 2>&1; then
    STATUS=1
    OUTPUT='schema 2 or 3 reference found in active implementation'
    fail "active catalog and state implementation remain schema 1"
else
    STATUS=0
    OUTPUT=
    pass "active catalog and state implementation remain schema 1"
fi

printf '%s config-state checks, %s failures\n' "$checks" "$failures"
[ "$failures" -eq 0 ]
