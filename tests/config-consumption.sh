#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
CLI="${PROJECT_ROOT}/bin/dotfiles"
PTY_CONFIRM="${PROJECT_ROOT}/tests/helpers/pty-confirm.py"
CONFIRM_HOOK="${PROJECT_ROOT}/tests/helpers/apply-confirmation-hook.sh"
TEST_PARENT=${TMPDIR:-/tmp}
TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-config-consumption-tests.XXXXXX")

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

REAL_CHEZMOI=$(command -v chezmoi)
PROBE_BIN="${TEST_ROOT}/probe-bin"
PROBE_LOG="${TEST_ROOT}/external-invocations.log"
ARTIFACT_ROOT="${TEST_ROOT}/share"
ARTIFACT_FILE="${ARTIFACT_ROOT}/zsh-autosuggestions/zsh-autosuggestions.zsh"
mkdir -p "$PROBE_BIN" "$(dirname -- "$ARTIFACT_FILE")" "${TEST_ROOT}/homes" "${TEST_ROOT}/roots" "${TEST_ROOT}/tmp"

for probe in brew mise apt apt-get dnf yum pacman apk installer zsh starship less more bat delta diff code vim vi nano open xdg-open op bw pass gopass keepassxc-cli vault sudo doas curl wget; do
    printf '%s\n' \
        '#!/bin/sh' \
        'printf "%s\n" "$0 $*" >> "$DOTFILES_CONSUMPTION_PROBE_LOG"' \
        'exit 97' > "${PROBE_BIN}/${probe}"
    chmod +x "${PROBE_BIN}/${probe}"
done
printf '%s\n' 'fixture artifact content must not be opened or invoked' > "$ARTIFACT_FILE"

export DOTFILES_CONSUMPTION_PROBE_LOG=$PROBE_LOG
export DOTFILES_CHEZMOI_BIN=$REAL_CHEZMOI
export DOTFILES_SHARE_ROOTS=$ARTIFACT_ROOT
export PATH="${PROBE_BIN}:/usr/bin:/bin"
export TMPDIR="${TEST_ROOT}/tmp"
export PYTHONDONTWRITEBYTECODE=1

# shellcheck source=../bin/dotfiles
source "$CLI"
# shellcheck source=../lib/config-state.sh
source "${PROJECT_ROOT}/lib/config-state.sh"
SOURCE_DIR=$PROJECT_ROOT
CHEZMOI_BIN=$REAL_CHEZMOI

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
    local text=$2
    case "$OUTPUT" in *"$text"*) pass "$name" ;; *) STATUS=1; fail "$name" ;; esac
}

check_not_contains() {
    local name=$1
    local text=$2
    case "$OUTPUT" in *"$text"*) STATUS=1; fail "$name" ;; *) pass "$name" ;; esac
}

new_root() {
    local root="${TEST_ROOT}/roots/$1"
    mkdir "$root"
    printf '%s\n' "$root"
}

new_home() {
    local home="${TEST_ROOT}/homes/$1"
    mkdir "$home"
    printf '%s\n' "$home"
}

run_cli() {
    local root=$1
    local home=$2
    shift 2
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    XDG_CONFIG_HOME="$root" HOME="$home" "$CLI" "$@" > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
}

run_cli_without_xdg() {
    local home=$1
    shift
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    env -u XDG_CONFIG_HOME HOME="$home" "$CLI" "$@" > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
}

run_cli_with_low_descriptors_occupied() {
    local root=$1
    local home=$2
    shift 2
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    (
        exec 3</dev/null 4</dev/null 5</dev/null 6</dev/null 7</dev/null 8</dev/null 9</dev/null
        XDG_CONFIG_HOME="$root" HOME="$home" "$CLI" "$@"
    ) > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
}

run_tty() {
    local answer=$1
    local root=$2
    local home=$3
    shift 3
    OUTPUT=$(XDG_CONFIG_HOME="$root" HOME="$home" "$PTY_CONFIRM" "$answer" "$CLI" "$@" 2>&1)
    STATUS=$?
}

write_state() {
    local root=$1
    local body=$2
    mkdir -p "$root/dotfiles"
    chmod 700 "$root/dotfiles"
    printf '%s\n' "$body" > "$root/dotfiles/active-selection.toml"
    chmod 600 "$root/dotfiles/active-selection.toml"
}

state_snapshot() {
    local root=$1
    local state="$root/dotfiles/active-selection.toml"
    local mtime
    if [ ! -e "$state" ] && [ ! -L "$state" ]; then
        printf 'missing\n'
        return
    fi
    printf 'identity=%s\n' "$(dotfiles_config_stat_identity "$state" 2>/dev/null || printf unavailable)"
    printf 'mode=%s\n' "$(dotfiles_config_stat_mode "$state" 2>/dev/null || printf unavailable)"
    mtime=$(stat -c '%Y' "$state" 2>/dev/null) ||
        mtime=$(stat -f '%m' "$state" 2>/dev/null) || mtime=unavailable
    printf 'mtime=%s\n' "$mtime"
    if [ -f "$state" ] && [ ! -L "$state" ]; then cksum "$state"; fi
    find "$root/dotfiles" -maxdepth 1 -print | LC_ALL=C sort
}

home_snapshot() {
    (
        CDPATH= cd -- "$1" || exit 1
        find . -print | LC_ALL=C sort
        find . -type f -exec cksum {} \; | LC_ALL=C sort
        find . -type l -print -exec readlink {} \; | LC_ALL=C sort
    )
}

PROFILE_BODY='schema = 1

[selection]
profile = "shell.minimal"
additional_modules = []'

STARSHIP_BODY='schema = 1

[selection]
modules = ["prompt.starship"]
additional_modules = []'

ORDERED_BODY='schema = 1

[selection]
modules = ["prompt.starship", "shell.zsh"]
additional_modules = ["shell.zsh.autosuggestions"]'

ADDITIONAL_BODY='schema = 1

[selection]
modules = ["shell.zsh"]
additional_modules = ["prompt.starship"]'

help_output=$("$CLI" help)
for syntax in \
    'dotfiles resolve [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]' \
    'dotfiles prerequisite check [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]' \
    'dotfiles plan [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]' \
    'dotfiles apply [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian] [--yes]'; do
    OUTPUT=$help_output
    case "$help_output" in *"$syntax"*) pass "help lists optional-base syntax: ${syntax%% *} ${syntax#* }" ;; *) STATUS=1; fail "help lists optional-base syntax" ;; esac
done

missing_root="${TEST_ROOT}/roots/missing"
missing_home=$(new_home missing)
run_cli "$missing_root" "$missing_home" resolve --help
check_status 'resolve help does not require local state' 0
[ ! -e "$missing_root" ] && pass 'help creates no configuration root' || { STATUS=1; OUTPUT='configuration root was created'; fail 'help creates no configuration root'; }

for command in resolve 'prerequisite check' plan apply; do
    case "$command" in
        resolve) run_cli "$missing_root" "$missing_home" resolve --platform debian ;;
        'prerequisite check') run_cli "$missing_root" "$missing_home" prerequisite check --platform debian ;;
        plan) run_cli "$missing_root" "$missing_home" plan --platform debian ;;
        apply) run_cli "$missing_root" "$missing_home" apply --platform debian --yes ;;
    esac
    check_status "${command} without a base uses missing-state status" 3
    check_contains "${command} missing state gives config-set guidance" 'Run dotfiles config set or pass --profile or --modules.'
done
[ ! -e "$missing_root" ] && pass 'missing-state consumers create no root, directory, lock, snapshot, or temporary file' || { STATUS=1; OUTPUT='missing root was created'; fail 'missing-state consumers are strictly read-only'; }

run_cli "$missing_root" "$missing_home" resolve --add prompt.starship --platform debian
check_status '--add alone is valid syntax and reaches saved-state loading' 3
run_cli "$missing_root" "$missing_home" resolve --profile shell.minimal --profile shell.minimal --platform debian
check_status 'repeated profile is status 2 before state access' 2
run_cli "$missing_root" "$missing_home" prerequisite check --modules prompt.starship --modules prompt.starship --platform debian
check_status 'repeated modules are status 2 before state access' 2
run_cli "$missing_root" "$missing_home" plan --modules prompt.starship --add shell.zsh --add shell.zsh --platform debian
check_status 'repeated additions are status 2 before state access' 2
run_cli "$missing_root" "$missing_home" apply --modules prompt.starship --platform debian --platform debian --yes
check_status 'repeated platform is status 2 before state access' 2
run_cli "$missing_root" "$missing_home" apply --modules prompt.starship --yes --yes
check_status 'repeated apply acknowledgement is status 2' 2
run_cli "$missing_root" "$missing_home" resolve --profile --platform debian
check_status 'option-shaped selector value is status 2' 2
run_cli "$missing_root" "$missing_home" plan unexpected --platform debian
check_status 'unexpected positional input is status 2' 2
run_cli "$missing_root" "$missing_home" resolve --yes
check_status '--yes remains invalid outside apply' 2

profile_root=$(new_root profile)
profile_home=$(new_home profile)
run_cli "$profile_root" "$profile_home" config set --profile shell.minimal --platform debian
check_status 'profile state setup succeeds' 0
profile_before=$(state_snapshot "$profile_root")
run_cli "$profile_root" "$profile_home" resolve --platform debian
local_profile_output=$STDOUT
check_status 'saved profile resolves' 0
run_cli "$profile_root" "$profile_home" resolve --profile shell.minimal --platform debian
check_equal 'saved and explicit profile resolution are byte-identical' "$STDOUT" "$local_profile_output"
run_cli "$profile_root" "$profile_home" resolve --add prompt.starship --platform debian
check_equal 'curated-profile overlap remains resolver-deduplicated' "$STDOUT" "$local_profile_output"
check_equal 'profile consumption preserves state metadata and bytes' "$(state_snapshot "$profile_root")" "$profile_before"

ordered_root=$(new_root ordered)
ordered_home=$(new_home ordered)
write_state "$ordered_root" "$ORDERED_BODY"
run_cli "$ordered_root" "$ordered_home" resolve --platform macos
ordered_local=$STDOUT
check_status 'ordered saved module intent resolves on macOS' 0
run_cli "$ordered_root" "$ordered_home" resolve --modules prompt.starship,shell.zsh --add shell.zsh.autosuggestions --platform macos
check_equal 'ordered saved modules and additions match explicit intent' "$STDOUT" "$ordered_local"

additional_root=$(new_root additional)
additional_home=$(new_home additional)
write_state "$additional_root" "$ADDITIONAL_BODY"
additional_before=$(state_snapshot "$additional_root")
run_cli "$additional_root" "$additional_home" resolve --add shell.zsh.autosuggestions --platform debian
local_add_output=$STDOUT
check_status 'invocation addition appends after saved additions' 0
run_cli "$additional_root" "$additional_home" resolve --modules shell.zsh --add prompt.starship,shell.zsh.autosuggestions --platform debian
check_equal 'saved plus invocation additions match equivalent explicit intent' "$STDOUT" "$local_add_output"
check_equal 'invocation additions do not persist or change state metadata' "$(state_snapshot "$additional_root")" "$additional_before"
run_cli "$additional_root" "$additional_home" resolve --add prompt.starship --platform debian
check_status 'duplicate saved and invocation additions fail as invalid intent' 3

starship_root=$(new_root starship)
starship_home=$(new_home starship)
write_state "$starship_root" "$STARSHIP_BODY"
starship_before=$(state_snapshot "$starship_root")
run_cli "$starship_root" "$starship_home" prerequisite check --platform debian
local_prerequisite=$OUTPUT
local_prerequisite_status=$STATUS
run_cli "$starship_root" "$starship_home" prerequisite check --modules prompt.starship --platform debian
check_equal 'saved and explicit prerequisite statuses match' "$local_prerequisite_status" "$STATUS"
check_equal 'saved and explicit prerequisite output is byte-identical' "$OUTPUT" "$local_prerequisite"

chmod -x "$PROBE_BIN/starship"
run_cli "$starship_root" "$starship_home" prerequisite check --platform debian
local_missing_prerequisite=$OUTPUT
local_missing_prerequisite_status=$STATUS
run_cli "$starship_root" "$starship_home" prerequisite check --modules prompt.starship --platform debian
check_equal 'saved and explicit missing-prerequisite statuses match' "$local_missing_prerequisite_status" "$STATUS"
check_equal 'saved and explicit missing-prerequisite output is byte-identical' "$OUTPUT" "$local_missing_prerequisite"

missing_plan_local_home=$(new_home plan-missing-local)
missing_plan_explicit_home=$(new_home plan-missing-explicit)
run_cli "$starship_root" "$missing_plan_local_home" plan --platform debian
local_missing_plan=$OUTPUT
local_missing_plan_status=$STATUS
run_cli "$starship_root" "$missing_plan_explicit_home" plan --modules prompt.starship --platform debian
check_equal 'saved and explicit missing-prerequisite plan statuses match' "$local_missing_plan_status" "$STATUS"
check_equal 'saved and explicit missing-prerequisite plan output is byte-identical' "$OUTPUT" "$local_missing_plan"
chmod +x "$PROBE_BIN/starship"

plan_local_home=$(new_home plan-local)
plan_explicit_home=$(new_home plan-explicit)
run_cli "$starship_root" "$plan_local_home" plan --platform debian
local_plan=$OUTPUT
local_plan_status=$STATUS
run_cli "$starship_root" "$plan_explicit_home" plan --modules prompt.starship --platform debian
check_equal 'saved and explicit plan statuses match' "$local_plan_status" "$STATUS"
check_equal 'saved and explicit plan output is byte-identical' "$OUTPUT" "$local_plan"

apply_local_home=$(new_home apply-local)
apply_explicit_home=$(new_home apply-explicit)
run_cli "$starship_root" "$apply_local_home" apply --platform debian --yes
local_apply=$OUTPUT
local_apply_status=$STATUS
check_status 'saved-selection apply succeeds' 0
run_cli "$starship_root" "$apply_explicit_home" apply --modules prompt.starship --platform debian --yes
check_equal 'saved and explicit apply statuses match' "$local_apply_status" "$STATUS"
check_equal 'saved and explicit apply output is byte-identical' "$OUTPUT" "$local_apply"
check_equal 'saved and explicit apply produce the same managed-home tree' "$(home_snapshot "$apply_local_home")" "$(home_snapshot "$apply_explicit_home")"
check_equal 'successful saved apply does not change selection state' "$(state_snapshot "$starship_root")" "$starship_before"
run_cli "$starship_root" "$apply_local_home" apply --platform debian
check_equal 'saved no-change apply is exact' "$STDOUT" 'No changes.'
local_no_change=$OUTPUT
local_no_change_status=$STATUS
run_cli "$starship_root" "$apply_explicit_home" apply --modules prompt.starship --platform debian
check_equal 'saved and explicit no-change apply statuses match' "$local_no_change_status" "$STATUS"
check_equal 'saved and explicit no-change apply output is byte-identical' "$OUTPUT" "$local_no_change"

partial_home=$(new_home apply-partial-failure)
export DOTFILES_REAL_CHEZMOI=$REAL_CHEZMOI
export DOTFILES_APPLY_CHEZMOI_BIN="${PROJECT_ROOT}/tests/helpers/chezmoi-apply-probe.sh"
export DOTFILES_EXPECTED_SOURCE_HOME="${PROJECT_ROOT}/home"
export DOTFILES_EXPECTED_APPLY_TARGETS=.config/starship.toml
export DOTFILES_ALLOWED_TEST_ROOT=$TEST_ROOT
export DOTFILES_APPLY_PRIVATE_PATH_LOG="${TEST_ROOT}/partial-private-paths.log"
export DOTFILES_APPLY_PRIVATE_MODE_LOG="${TEST_ROOT}/partial-private-modes.log"
export DOTFILES_APPLY_INVOCATION_LOG="${TEST_ROOT}/partial-invocations.log"
export DOTFILES_APPLY_PROBE_MODE=fail-target
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
run_cli "$starship_root" "$partial_home" apply --platform debian --yes
check_status 'saved-selection partial apply failure keeps status 6' 6
check_contains 'saved-selection partial apply failure reports exact outcome' 'Apply failed: 0 completed, 1 failed, 0 unattempted'
[ ! -e "$partial_home/.config/starship.toml" ] && pass 'saved-selection partial apply failure verifies no completed target' || { STATUS=1; OUTPUT='failed target exists'; fail 'saved-selection partial apply failure verifies no completed target'; }
check_equal 'saved-selection partial apply failure leaves selection unchanged' "$(state_snapshot "$starship_root")" "$starship_before"
unset DOTFILES_REAL_CHEZMOI DOTFILES_APPLY_CHEZMOI_BIN DOTFILES_EXPECTED_SOURCE_HOME
unset DOTFILES_EXPECTED_APPLY_TARGETS DOTFILES_ALLOWED_TEST_ROOT
unset DOTFILES_APPLY_PRIVATE_PATH_LOG DOTFILES_APPLY_PRIVATE_MODE_LOG
unset DOTFILES_APPLY_INVOCATION_LOG DOTFILES_APPLY_PROBE_MODE DOTFILES_APPLY_PROBE_TARGET

cancel_home=$(new_home apply-cancel)
cancel_before=$(home_snapshot "$cancel_home")
run_tty no "$starship_root" "$cancel_home" apply --platform debian
check_status 'saved apply cancellation succeeds' 0
check_contains 'saved apply cancellation is explicit' 'Cancelled. No changes were applied.'
check_equal 'saved apply cancellation leaves managed home unchanged' "$(home_snapshot "$cancel_home")" "$cancel_before"
check_equal 'saved apply cancellation leaves selection unchanged' "$(state_snapshot "$starship_root")" "$starship_before"

export DOTFILES_PTY_CONFIRM_HOOK=$CONFIRM_HOOK
for drift_mode in delete-selection corrupt-selection change-selection replace-identical-selection symlink-selection; do
    drift_root=$(new_root "drift-${drift_mode}")
    drift_home=$(new_home "drift-${drift_mode}")
    write_state "$drift_root" "$STARSHIP_BODY"
    export DOTFILES_CONFIRM_HOOK_MODE=$drift_mode
    export DOTFILES_CONFIRM_HOOK_TARGET="${drift_root}/dotfiles/active-selection.toml"
    run_tty yes "$drift_root" "$drift_home" apply --platform debian
    check_status "${drift_mode} fails before managed-home mutation" 3
    check_contains "${drift_mode} requests apply rerun" 'rerun dotfiles apply'
    [ ! -e "$drift_home/.config/starship.toml" ] && pass "${drift_mode} invokes no managed-target mutation" || { STATUS=1; OUTPUT='managed target exists'; fail "${drift_mode} invokes no managed-target mutation"; }
done

equivalent_drift_root=$(new_root drift-equivalent-selection)
equivalent_drift_home=$(new_home drift-equivalent-selection)
write_state "$equivalent_drift_root" "$PROFILE_BODY"
export DOTFILES_CONFIRM_HOOK_MODE=change-equivalent-selection
export DOTFILES_CONFIRM_HOOK_TARGET="${equivalent_drift_root}/dotfiles/active-selection.toml"
run_tty yes "$equivalent_drift_root" "$equivalent_drift_home" apply --platform debian
check_status 'equivalent resolved intent replacement fails before managed-home mutation' 3
check_contains 'equivalent resolved intent replacement requests apply rerun' 'rerun dotfiles apply'
[ ! -e "$equivalent_drift_home/.zshrc" ] && pass 'equivalent resolved intent replacement invokes no managed-target mutation' || { STATUS=1; OUTPUT='managed target exists'; fail 'equivalent resolved intent replacement invokes no managed-target mutation'; }
unset DOTFILES_PTY_CONFIRM_HOOK DOTFILES_CONFIRM_HOOK_MODE DOTFILES_CONFIRM_HOOK_TARGET

invalid_root=$(new_root invalid-explicit-bypass)
invalid_home=$(new_home invalid-explicit-bypass)
write_state "$invalid_root" 'not canonical private state'
invalid_before=$(state_snapshot "$invalid_root")
run_cli "$invalid_root" "$invalid_home" resolve --modules prompt.starship --platform debian
check_status 'explicit resolve ignores invalid local state' 0
run_cli "$invalid_root" "$invalid_home" prerequisite check --modules prompt.starship --platform debian
check_status 'explicit prerequisite check ignores invalid local state' 0
run_cli "$invalid_root" "$invalid_home" plan --modules prompt.starship --platform debian
check_status 'explicit plan ignores invalid local state' 0
run_cli "$invalid_root" "$invalid_home" apply --modules prompt.starship --platform debian --yes
check_status 'explicit apply ignores invalid local state' 0
check_equal 'explicit consumers never repair or rewrite invalid local state' "$(state_snapshot "$invalid_root")" "$invalid_before"

copy_root="${TEST_ROOT}/without-config-state"
mkdir "$copy_root"
cp -R "${PROJECT_ROOT}/bin" "${PROJECT_ROOT}/lib" "${PROJECT_ROOT}/home" "${PROJECT_ROOT}/.chezmoidata" "$copy_root/"
rm -f -- "$copy_root/lib/config-state.sh"
copy_home=$(new_home no-state-component)
for command in resolve prerequisite plan apply; do
    case "$command" in
        resolve) OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" resolve --modules prompt.starship --platform debian 2>&1); STATUS=$? ;;
        prerequisite) OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" prerequisite check --modules prompt.starship --platform debian 2>&1); STATUS=$? ;;
        plan) OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" plan --modules prompt.starship --platform debian 2>&1); STATUS=$? ;;
        apply) OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" apply --modules prompt.starship --platform debian --yes 2>&1); STATUS=$? ;;
    esac
    check_status "explicit ${command} does not require the config-state component" 0
done
OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" resolve --platform debian 2>&1)
STATUS=$?
check_status 'saved selection reports missing state component as status 4' 4

safety_home=$(new_home safety)
for fixture in noncanonical schema unknown-field both-bases empty-modules unknown-module; do
    safety_root=$(new_root "unsafe-${fixture}")
    case "$fixture" in
        noncanonical) body=$'# comment\nschema = 1\n\n[selection]\nmodules = ["prompt.starship"]\nadditional_modules = []' ;;
        schema) body=$'schema = 2\n\n[selection]\nmodules = ["prompt.starship"]\nadditional_modules = []' ;;
        unknown-field) body=$'schema = 1\n\n[selection]\nmodules = ["prompt.starship"]\nadditional_modules = []\nunexpected = "value"' ;;
        both-bases) body=$'schema = 1\n\n[selection]\nprofile = "shell.minimal"\nmodules = ["prompt.starship"]\nadditional_modules = []' ;;
        empty-modules) body=$'schema = 1\n\n[selection]\nmodules = []\nadditional_modules = []' ;;
        unknown-module) body=$'schema = 1\n\n[selection]\nmodules = ["shell.unknown"]\nadditional_modules = []' ;;
    esac
    write_state "$safety_root" "$body"
    fixture_before=$(state_snapshot "$safety_root")
    run_cli "$safety_root" "$safety_home" resolve --platform debian
    check_status "${fixture} local state fails closed" 3
    check_equal "${fixture} local state is not repaired" "$(state_snapshot "$safety_root")" "$fixture_before"
done

mode_root=$(new_root unsafe-mode)
write_state "$mode_root" "$STARSHIP_BODY"
chmod 644 "$mode_root/dotfiles/active-selection.toml"
run_cli "$mode_root" "$safety_home" resolve --platform debian
check_status 'unsafe state mode fails closed' 3

directory_mode_root=$(new_root unsafe-directory-mode)
write_state "$directory_mode_root" "$STARSHIP_BODY"
chmod 755 "$directory_mode_root/dotfiles"
run_cli "$directory_mode_root" "$safety_home" resolve --platform debian
check_status 'unsafe dedicated-directory mode fails closed' 3

symlink_root=$(new_root symlink-state)
mkdir "$symlink_root/dotfiles"
chmod 700 "$symlink_root/dotfiles"
ln -s /dev/null "$symlink_root/dotfiles/active-selection.toml"
run_cli "$symlink_root" "$safety_home" resolve --platform debian
check_status 'state symlink fails closed without being opened' 3

hardlink_root=$(new_root hardlink-state)
write_state "$hardlink_root" "$STARSHIP_BODY"
ln "$hardlink_root/dotfiles/active-selection.toml" "$hardlink_root/dotfiles/selection-alias"
run_cli "$hardlink_root" "$safety_home" resolve --platform debian
check_status 'hard-linked state fails closed' 3

type_root=$(new_root wrong-state-type)
mkdir "$type_root/dotfiles"
chmod 700 "$type_root/dotfiles"
mkdir "$type_root/dotfiles/active-selection.toml"
run_cli "$type_root" "$safety_home" resolve --platform debian
check_status 'wrong state type fails closed' 3

inside_project_root=$PROJECT_ROOT
run_cli "$inside_project_root" "$safety_home" resolve --platform debian
check_status 'configuration root inside the repository fails closed' 3

real_symlink_root=$(new_root symlink-root-target)
write_state "$real_symlink_root" "$STARSHIP_BODY"
symlink_config_root="${TEST_ROOT}/roots/symlink-root"
ln -s "$real_symlink_root" "$symlink_config_root"
run_cli "$symlink_config_root" "$safety_home" resolve --platform debian
check_status 'symlinked standard configuration root fails closed' 3

precedence_home=$(new_home precedence)
mkdir -p "$precedence_home/.config"
chmod 700 "$precedence_home/.config"
write_state "$precedence_home/.config" "$PROFILE_BODY"
precedence_xdg=$(new_root precedence-xdg)
write_state "$precedence_xdg" "$STARSHIP_BODY"
run_cli "$precedence_xdg" "$precedence_home" resolve --platform debian
check_equal 'non-empty XDG root takes precedence over HOME fallback' "$STDOUT" 'prompt.starship'
run_cli_without_xdg "$precedence_home" resolve --platform debian
check_equal 'unset XDG uses HOME fallback selection' "$STDOUT" $'shell.zsh\nshell.zsh.autosuggestions\nprompt.starship'

DRIFT_STATE=
replace_reader_bytes() {
    printf '%s\n' "$PROFILE_BODY" > "$DRIFT_STATE"
    chmod 600 "$DRIFT_STATE"
}
append_reader_bytes() {
    printf '\n' >> "$DRIFT_STATE"
}
replace_reader_identity() {
    local replacement="${DRIFT_STATE}.replacement"
    cp -- "$DRIFT_STATE" "$replacement"
    chmod 600 "$replacement"
    mv -f -- "$replacement" "$DRIFT_STATE"
}

reader_root=$(new_root reader-drift-bytes)
write_state "$reader_root" "$STARSHIP_BODY"
DRIFT_STATE="$reader_root/dotfiles/active-selection.toml"
DOTFILES_CONFIG_TEST_AFTER_FIRST_READ=replace_reader_bytes
OUTPUT=$(dotfiles_config_state_load_internal "$reader_root" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_FIRST_READ
check_status 'observable byte drift during read fails closed' 3
check_contains 'byte drift diagnostic is actionable' 'changed or was replaced while being read'

reader_size_root=$(new_root reader-drift-size)
write_state "$reader_size_root" "$STARSHIP_BODY"
DRIFT_STATE="$reader_size_root/dotfiles/active-selection.toml"
DOTFILES_CONFIG_TEST_AFTER_FIRST_READ=append_reader_bytes
OUTPUT=$(dotfiles_config_state_load_internal "$reader_size_root" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_FIRST_READ
check_status 'observable same-identity size drift during read fails closed' 3
check_contains 'same-identity size drift is not capability exhaustion' 'changed or was replaced while being read'

reader_identity_root=$(new_root reader-drift-identity)
write_state "$reader_identity_root" "$STARSHIP_BODY"
DRIFT_STATE="$reader_identity_root/dotfiles/active-selection.toml"
DOTFILES_CONFIG_TEST_AFTER_READ_VALIDATION=replace_reader_identity
OUTPUT=$(dotfiles_config_state_load_internal "$reader_identity_root" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_READ_VALIDATION
check_status 'observable identity drift during read fails closed' 3

stable_root=$(new_root stable-read)
stable_home=$(new_home stable-read)
write_state "$stable_root" "$STARSHIP_BODY"
stable_before=$(state_snapshot "$stable_root")
run_cli "$stable_root" "$stable_home" resolve --platform macos
check_status 'strict read succeeds on macOS input' 0
check_equal 'strict read creates no lock, snapshot, temporary file, or metadata change' "$(state_snapshot "$stable_root")" "$stable_before"
run_cli_with_low_descriptors_occupied "$stable_root" "$stable_home" resolve --platform macos
check_status 'strict read succeeds with inherited descriptors 3 through 9 occupied' 0
check_equal 'occupied low descriptors preserve exact resolution output' "$STDOUT" 'prompt.starship'

fail_read_handle_open() {
    return 4
}
DOTFILES_CONFIG_TEST_READ_HANDLE_OPEN=fail_read_handle_open
OUTPUT=$(dotfiles_config_state_load_internal "$stable_root" macos 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_READ_HANDLE_OPEN
check_status 'read-handle allocation exhaustion is status 4' 4
check_contains 'read-handle allocation exhaustion has capability guidance' 'local selection read handle is unavailable'
check_not_contains 'read-handle allocation exhaustion is not reported as state drift' 'changed or was replaced while being read'

privacy_root=$(new_root privacy)
write_state "$privacy_root" 'private-state-contents-must-not-appear'
run_cli "$privacy_root" "$safety_home" resolve --platform debian
check_status 'invalid private state uses status 3' 3
check_not_contains 'diagnostic hides raw configuration root' "$privacy_root"
check_not_contains 'diagnostic hides raw HOME' "$safety_home"
check_not_contains 'diagnostic hides username' "$(id -un)"
check_not_contains 'diagnostic hides hostname' "$(hostname)"
check_not_contains 'diagnostic hides state contents' 'private-state-contents-must-not-appear'
check_contains 'diagnostic uses abbreviated standard root' '$XDG_CONFIG_HOME/dotfiles/active-selection.toml'

if [ ! -e "$PROBE_LOG" ]; then
    STATUS=0
    OUTPUT=
    pass 'consumption invokes no provider, installer, prerequisite, artifact, network, privilege, pager, or editor helper'
else
    STATUS=97
    OUTPUT=$(< "$PROBE_LOG")
    fail 'consumption invokes no external capability helper'
fi

if [ "$failures" -ne 0 ]; then
    printf '%s config-consumption checks, %s failures\n' "$checks" "$failures" >&2
    exit 1
fi

printf '%s config-consumption checks passed\n' "$checks"
