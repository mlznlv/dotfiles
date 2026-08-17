#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
CLI="${PROJECT_ROOT}/bin/dotfiles"
PTY_HELPER="${PROJECT_ROOT}/tests/helpers/pty-interactive.py"
STATE_HOOK="${PROJECT_ROOT}/tests/helpers/interactive-state-hook.sh"
TEST_PARENT=${TMPDIR:-/tmp}
TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-config-interactive-tests.XXXXXX")

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

REAL_CHEZMOI=$(command -v chezmoi)
PYTHON_BIN=$(command -v python3)
PROBE_BIN="${TEST_ROOT}/probe-bin"
PROBE_LOG="${TEST_ROOT}/external-invocations.log"
CHEZMOI_LOG="${TEST_ROOT}/chezmoi-invocations.log"
CHEZMOI_PROBE="${TEST_ROOT}/chezmoi-probe"
mkdir -p "$PROBE_BIN"
: > "$PROBE_LOG"
: > "$CHEZMOI_LOG"

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
export PATH="${PROBE_BIN}:/usr/bin:/bin"

stage_fixture() {
    local name=$1
    local target="${TEST_ROOT}/fixtures/${name}/.chezmoidata"
    mkdir -p "$target"
    cp -R "${PROJECT_ROOT}/tests/fixtures/${name}/catalog/." "$target/"
}

for fixture in valid cycle source-collision empty-inventory; do
    stage_fixture "$fixture"
done

failures=0
checks=0
STATUS=0
STDOUT=
STDERR=
OUTPUT=
ALL_OUTPUT=
CASE_ROOT=
CASE_HOME=
CASE_CONFIG=

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

record_output() {
    OUTPUT="${STDOUT}${STDOUT:+${STDERR:+$'\n'}}${STDERR}"
    ALL_OUTPUT="${ALL_OUTPUT}${ALL_OUTPUT:+$'\n'}${OUTPUT}"
}

run_command() {
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    "$@" > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    record_output
}

run_closed_stdin() {
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    "$@" <&- > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    record_output
}

run_piped() {
    local input=$1
    shift
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    printf '%s' "$input" | "$@" > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    record_output
}

run_tty() {
    local events=$1
    local source_dir=$2
    local config_root=$3
    local home=$4
    shift 4
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    env \
        DOTFILES_SOURCE_DIR="$source_dir" \
        XDG_CONFIG_HOME="$config_root" \
        HOME="$home" \
        PYTHONPYCACHEPREFIX="${TEST_ROOT}/python-cache" \
        "$PYTHON_BIN" "$PTY_HELPER" "$events" "$CLI" "$@" \
        > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    record_output
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

check_path_absent() {
    local name=$1
    local path=$2
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        pass "$name"
    else
        STATUS=1
        OUTPUT="unexpected path exists"
        fail "$name"
    fi
}

mode_of() {
    if stat -f '%Lp' "$1" >/dev/null 2>&1; then
        stat -f '%Lp' "$1"
    else
        stat -c '%a' "$1"
    fi
}

identity_of() {
    if stat -f '%d:%i' "$1" >/dev/null 2>&1; then
        stat -f '%d:%i' "$1"
    else
        stat -c '%d:%i' "$1"
    fi
}

tree_snapshot() {
    (
        CDPATH= cd -- "$1" || exit 1
        find . -print | LC_ALL=C sort
        find . -type f -exec cksum {} \; | LC_ALL=C sort
        find . -type l -print -exec readlink {} \; | LC_ALL=C sort
    )
}

new_case() {
    local name=$1
    CASE_ROOT="${TEST_ROOT}/cases/${name}-${checks}"
    CASE_HOME="${CASE_ROOT}/home"
    CASE_CONFIG="${CASE_ROOT}/config"
    mkdir -p "$CASE_HOME"
    printf 'managed-home-sentinel\n' > "$CASE_HOME/sentinel"
}

write_state() {
    local root=$1
    local body=$2
    mkdir -p "$root/dotfiles"
    chmod 700 "$root/dotfiles"
    printf '%s\n' "$body" > "$root/dotfiles/active-selection.toml"
    chmod 600 "$root/dotfiles/active-selection.toml"
}

assert_no_debris() {
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
        OUTPUT='local selection debris remains'
        fail "$name"
    fi
}

selection_events() {
    "$PYTHON_BIN" -c '
import json, sys
kind, base, additional, confirmation, hook = sys.argv[1:]
events = [{"wait": "Base type (profile or modules):\n", "send": kind}]
if kind == "profile":
    events.append({"wait": "Profile ID:\n", "send": base})
elif kind == "modules":
    events.append({"wait": "Module IDs (comma-separated):\n", "send": base})
else:
    print(json.dumps(events))
    raise SystemExit
events.append({"wait": "Additional module IDs (comma-separated, empty for none):\n", "send": additional})
if confirmation != "__NONE__":
    event = {"wait": "Save this local selection? Type yes to continue:\n"}
    if confirmation == "__EOF__":
        event["eof"] = True
    else:
        event["send"] = confirmation
    if hook == "hook":
        event["hook"] = True
    events.append(event)
print(json.dumps(events))
' "$1" "$2" "$3" "$4" "${5:-nohook}"
}

base_event() {
    "$PYTHON_BIN" -c 'import json, sys; print(json.dumps([{"wait": "Base type (profile or modules):\n", "send": sys.argv[1]}]))' "$1"
}

PROFILE_BODY='schema = 1

[selection]
profile = "shell.minimal"
additional_modules = []'

MODULE_BODY='schema = 1

[selection]
modules = ["prompt.starship", "shell.zsh"]
additional_modules = ["shell.zsh.autosuggestions"]'

STARSHIP_BODY='schema = 1

[selection]
modules = ["prompt.starship"]
additional_modules = []'

PROFILE_INVENTORY='Available profiles for debian:
  shell.minimal
Available modules for debian:
  prompt.starship
  shell.zsh
  shell.zsh.autosuggestions'

MACOS_INVENTORY='Available profiles for macos:
  shell.minimal
Available modules for macos:
  prompt.starship
  shell.zsh
  shell.zsh.autosuggestions'

run_command "$CLI" help
check_status "help succeeds" 0
check_contains "help lists exact interactive syntax" 'dotfiles config interactive [--platform macos|debian]'
check_not_contains "help still omits inspect" 'config inspect'
check_not_contains "help still omits doctor" 'config doctor'
check_not_contains "help still omits cache reset" 'cache reset'

for arguments in \
    '--platform' \
    '--platform --help' \
    '--platform debian --platform macos' \
    '--profile shell.minimal' \
    '--modules shell.zsh' \
    '--add prompt.starship' \
    '--yes' \
    '--destination /tmp' \
    '--unknown' \
    'positional'; do
    new_case "syntax-${checks}"
    # Intentional word splitting supplies static invalid argument fixtures.
    # shellcheck disable=SC2086
    run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive $arguments
    check_status "interactive syntax rejects ${arguments}" 2
    check_not_contains "syntax rejection prints no inventory for ${arguments}" 'Available profiles'
    check_path_absent "syntax rejection creates no configuration root for ${arguments}" "$CASE_CONFIG"
done

run_command "$CLI" config interactive --help
check_status "interactive help does not require a terminal" 0
check_contains "interactive help uses built-in usage" 'dotfiles config interactive [--platform macos|debian]'

new_case non-terminal
CHEZMOI_BEFORE=$(wc -l < "$CHEZMOI_LOG" 2>/dev/null || printf 0)
run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive --platform debian
check_status "redirected stdin is rejected" 2
check_equal "non-terminal rejection writes no stdout" "$STDOUT" ""
check_contains "non-terminal rejection is actionable" 'config interactive requires terminal stdin'
check_not_contains "non-terminal rejection prints no inventory" 'Available profiles'
check_path_absent "non-terminal rejection creates no configuration root" "$CASE_CONFIG"
check_equal "non-terminal rejection reads no catalog" "$(wc -l < "$CHEZMOI_LOG" 2>/dev/null || printf 0)" "$CHEZMOI_BEFORE"

new_case non-terminal-existing-state
write_state "$CASE_CONFIG" 'malformed current state'
NON_TERMINAL_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
NON_TERMINAL_IDENTITY=$(identity_of "$NON_TERMINAL_PATH")
NON_TERMINAL_CHECKSUM=$(cksum < "$NON_TERMINAL_PATH")
run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive --platform debian
check_status "non-terminal input fails before existing-state validation" 2
check_contains "non-terminal existing-state rejection remains actionable" 'config interactive requires terminal stdin'
check_equal "non-terminal rejection preserves existing state identity" "$(identity_of "$NON_TERMINAL_PATH")" "$NON_TERMINAL_IDENTITY"
check_equal "non-terminal rejection preserves existing state bytes" "$(cksum < "$NON_TERMINAL_PATH")" "$NON_TERMINAL_CHECKSUM"
assert_no_debris "non-terminal rejection creates no lock or temporary material" "$CASE_CONFIG/dotfiles"

new_case piped-input
run_piped $'profile\nshell.minimal\n\nyes\n' env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive --platform debian
check_status "piped stdin is rejected" 2
check_path_absent "piped stdin creates no configuration root" "$CASE_CONFIG"

new_case closed-input
run_closed_stdin env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive --platform debian
check_status "closed stdin is rejected" 2
check_path_absent "closed stdin creates no configuration root" "$CASE_CONFIG"

new_case invalid-platform
run_tty '[]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform linux
check_status "invalid terminal platform is rejected" 3
check_not_contains "invalid platform prints no inventory" 'Available profiles'
check_path_absent "invalid platform creates no configuration root" "$CASE_CONFIG"

new_case profile-cancel
HOME_BEFORE=$(tree_snapshot "$CASE_HOME")
EVENTS=$(selection_events profile shell.minimal "" no)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
EXPECTED_PROFILE_CANCEL="${PROFILE_INVENTORY}
Base type (profile or modules):
Profile ID:
Additional module IDs (comma-separated, empty for none):
Proposed local selection:
Base: profile shell.minimal
Additional modules: none
Resolved modules for debian:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship
Save this local selection? Type yes to continue:
Cancelled. Local selection was not changed.
Managed home configuration: unchanged."
check_status "profile cancellation succeeds" 0
check_equal "profile inventory, prompts, proposal, and cancellation are exact" "$STDOUT" "$EXPECTED_PROFILE_CANCEL"
check_not_contains "profile flow omits the module-base prompt" 'Module IDs (comma-separated):'
check_equal "profile cancellation writes no stderr" "$STDERR" ""
check_path_absent "missing-state cancellation creates no configuration root" "$CASE_CONFIG"
check_equal "profile cancellation leaves managed HOME unchanged" "$(tree_snapshot "$CASE_HOME")" "$HOME_BEFORE"

new_case detected-platform
EVENTS=$(selection_events profile shell.minimal "" no)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive
check_status "interactive platform detection succeeds" 0
case "$(uname -s)" in Darwin) DETECTED_PLATFORM=macos ;; *) DETECTED_PLATFORM=debian ;; esac
check_contains "detected platform is used in inventory" "Available profiles for ${DETECTED_PLATFORM}:"
check_path_absent "detected-platform cancellation creates no state" "$CASE_CONFIG"

new_case empty-inventory
EVENTS='[{"wait":"Base type (profile or modules):\n","eof":true}]'
run_tty "$EVENTS" "${TEST_ROOT}/fixtures/empty-inventory" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "empty inventory reaches the first prompt" 2
check_contains "empty profile category prints none" $'Available profiles for debian:\n  none'
check_contains "empty module category prints none" $'Available modules for debian:\n  none'
check_not_contains "empty inventory leaks no catalog metadata" 'summary'
check_path_absent "empty inventory EOF creates no state" "$CASE_CONFIG"

for invalid_type in '' Profile MODULES 1 prof modules1 ' profile'; do
    new_case "invalid-base-${checks}"
    EVENTS=$(base_event "$invalid_type")
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "literal base type is rejected: ${invalid_type:-empty}" 3
    check_not_contains "invalid base type shows no profile prompt: ${invalid_type:-empty}" 'Profile ID:'
    check_not_contains "invalid base type shows no module prompt: ${invalid_type:-empty}" 'Module IDs (comma-separated):'
    check_not_contains "invalid base type shows no additions prompt: ${invalid_type:-empty}" 'Additional module IDs'
    check_path_absent "invalid base type creates no state: ${invalid_type:-empty}" "$CASE_CONFIG"
done

for invalid_profile in '' Shell.Minimal 1 shell '"shell.minimal"' 'shell.minimal ' $'shell.minimal\t' shell.unknown; do
    new_case "invalid-profile-${checks}"
    EVENTS=$(selection_events profile "$invalid_profile" "" __NONE__)
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "literal profile input is rejected: ${invalid_profile:-empty}" 3
    check_contains "invalid profile still requests additions: ${invalid_profile:-empty}" 'Additional module IDs (comma-separated, empty for none):'
    check_not_contains "invalid profile prints no proposal: ${invalid_profile:-empty}" 'Proposed local selection:'
    check_path_absent "invalid profile creates no state: ${invalid_profile:-empty}" "$CASE_CONFIG"
done

for invalid_modules in '' 1 shell 'Shell.Zsh' '"shell.zsh"' 'shell.zsh ' 'shell.zsh,prompt.starship,' 'shell.zsh,,prompt.starship' 'shell.zsh, prompt.starship' 'shell.zsh,shell.zsh' 'shell.zsh\prompt.starship' 'shell.zsh;prompt.starship' $'shell.zsh\t' shell.unknown; do
    new_case "invalid-modules-${checks}"
    EVENTS=$(selection_events modules "$invalid_modules" "" __NONE__)
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "literal module input is rejected: ${invalid_modules:-empty}" 3
    check_contains "invalid modules still request additions: ${invalid_modules:-empty}" 'Additional module IDs (comma-separated, empty for none):'
    check_not_contains "invalid modules print no proposal: ${invalid_modules:-empty}" 'Proposed local selection:'
    check_path_absent "invalid modules create no state: ${invalid_modules:-empty}" "$CASE_CONFIG"
done

for invalid_additions in 'prompt.starship,prompt.starship' 'shell.zsh' ' prompt.starship' 'prompt.starship ' 'prompt.starship,' 'prompt.starship,,shell.zsh' 'PROMPT.starship' '"prompt.starship"' 'prompt.starship;false' $'prompt.starship\t' prompt.unknown; do
    new_case "invalid-additions-${checks}"
    EVENTS=$(selection_events modules shell.zsh "$invalid_additions" __NONE__)
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "literal additions are rejected: ${invalid_additions}" 3
    check_not_contains "invalid additions print no proposal: ${invalid_additions}" 'Proposed local selection:'
    check_path_absent "invalid additions create no state: ${invalid_additions}" "$CASE_CONFIG"
done

new_case dependency-expansion
EVENTS=$(selection_events modules shell.zsh.autosuggestions "" no)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "dependency-expanded proposal succeeds" 0
check_contains "dependency appears before the selected dependent" $'Resolved modules for debian:\n  shell.zsh\n  shell.zsh.autosuggestions'
check_path_absent "dependency proposal cancellation creates no state" "$CASE_CONFIG"

for fixture_case in exclusive conflict unsupported cycle collision; do
    new_case "composition-${fixture_case}"
    case "$fixture_case" in
        exclusive)
            SOURCE="${TEST_ROOT}/fixtures/valid"
            PLATFORM=macos
            BASE=terminal.ghostty,terminal.wezterm
            ;;
        conflict)
            SOURCE="${TEST_ROOT}/fixtures/valid"
            PLATFORM=macos
            BASE=shell.zsh,terminal.wezterm
            ;;
        unsupported)
            SOURCE="${TEST_ROOT}/fixtures/valid"
            PLATFORM=debian
            BASE=terminal.ghostty
            ;;
        cycle)
            SOURCE="${TEST_ROOT}/fixtures/cycle"
            PLATFORM=debian
            BASE=shell.alpha
            ;;
        collision)
            SOURCE="${TEST_ROOT}/fixtures/source-collision"
            PLATFORM=debian
            BASE=shell.alpha,shell.beta
            ;;
    esac
    if [ "$fixture_case" = cycle ]; then
        EVENTS='[]'
    else
        EVENTS=$(selection_events modules "$BASE" "" __NONE__)
    fi
    run_tty "$EVENTS" "$SOURCE" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform "$PLATFORM"
    check_status "${fixture_case} composition fails before confirmation" 3
    check_not_contains "${fixture_case} composition prints no proposal" 'Proposed local selection:'
    check_path_absent "${fixture_case} composition creates no state" "$CASE_CONFIG"
    if [ "$fixture_case" = cycle ]; then
        check_not_contains "invalid catalog prints no partial inventory" 'Available profiles'
    fi
done

new_case incomplete-base-type
run_tty '[{"wait":"Base type (profile or modules):\n","eof":true}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "EOF at base type is incomplete" 2
check_contains "base-type EOF is diagnosed" 'incomplete interactive local selection'
check_path_absent "base-type EOF creates no state" "$CASE_CONFIG"

new_case incomplete-profile
run_tty '[{"wait":"Base type (profile or modules):\n","send":"profile"},{"wait":"Profile ID:\n","eof":true}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "EOF at profile is incomplete" 2
check_path_absent "profile EOF creates no state" "$CASE_CONFIG"

new_case incomplete-modules
run_tty '[{"wait":"Base type (profile or modules):\n","send":"modules"},{"wait":"Module IDs (comma-separated):\n","eof":true}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "EOF at module base is incomplete" 2
check_path_absent "module EOF creates no state" "$CASE_CONFIG"

new_case incomplete-additions
run_tty '[{"wait":"Base type (profile or modules):\n","send":"profile"},{"wait":"Profile ID:\n","send":"shell.minimal"},{"wait":"Additional module IDs (comma-separated, empty for none):\n","eof":true}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "EOF at additions is incomplete" 2
check_path_absent "additions EOF creates no state" "$CASE_CONFIG"

for answer in Yes YES y 'yes ' ' yes' $'yes\t' 'yes please' '' __EOF__; do
    new_case "cancel-${checks}"
    EVENTS=$(selection_events profile shell.minimal "" "$answer")
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "non-exact confirmation cancels: ${answer:-empty}" 0
    check_contains "non-exact confirmation reports cancellation: ${answer:-empty}" 'Cancelled. Local selection was not changed.'
    check_not_contains "non-exact confirmation never reports saved: ${answer:-empty}" 'Local selection saved.'
    check_path_absent "non-exact confirmation creates no root: ${answer:-empty}" "$CASE_CONFIG"
done

new_case save-profile
HOME_BEFORE=$(tree_snapshot "$CASE_HOME")
EVENTS=$(selection_events profile shell.minimal "" yes)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "exact yes saves a profile selection" 0
check_contains "profile save reports success" 'Local selection saved.'
check_equal "profile save writes no stderr" "$STDERR" ""
check_equal "profile save emits canonical schema-1 bytes" "$(< "$CASE_CONFIG/dotfiles/active-selection.toml")" "$PROFILE_BODY"
check_equal "interactive directory mode is 0700" "$(mode_of "$CASE_CONFIG/dotfiles")" 700
check_equal "interactive file mode is 0600" "$(mode_of "$CASE_CONFIG/dotfiles/active-selection.toml")" 600
check_equal "interactive profile save leaves managed HOME unchanged" "$(tree_snapshot "$CASE_HOME")" "$HOME_BEFORE"
PROFILE_INTERACTIVE_FILE="$CASE_CONFIG/dotfiles/active-selection.toml"

new_case set-profile-reference
run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config set --profile shell.minimal --platform debian
check_status "config set profile reference succeeds" 0
if cmp -s "$PROFILE_INTERACTIVE_FILE" "$CASE_CONFIG/dotfiles/active-selection.toml"; then
    pass "interactive and config set profile bytes are identical"
else
    STATUS=1
    OUTPUT='profile state bytes differ'
    fail "interactive and config set profile bytes are identical"
fi

new_case save-modules
EVENTS=$(selection_events modules prompt.starship,shell.zsh shell.zsh.autosuggestions yes)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform macos
check_status "exact yes saves ordered modules and additions" 0
check_contains "macOS inventory preserves deterministic catalog order" "$MACOS_INVENTORY"
check_contains "module flow uses only the module-base prompt" 'Module IDs (comma-separated):'
check_not_contains "module flow omits the profile prompt" 'Profile ID:'
check_contains "module proposal preserves base order" 'Base: modules prompt.starship,shell.zsh'
check_contains "module proposal preserves addition order" 'Additional modules: shell.zsh.autosuggestions'
check_equal "module flow emits canonical schema-1 bytes" "$(< "$CASE_CONFIG/dotfiles/active-selection.toml")" "$MODULE_BODY"
MODULE_INTERACTIVE_FILE="$CASE_CONFIG/dotfiles/active-selection.toml"

new_case set-module-reference
run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config set --modules prompt.starship,shell.zsh --add shell.zsh.autosuggestions --platform macos
check_status "config set module reference succeeds" 0
if cmp -s "$MODULE_INTERACTIVE_FILE" "$CASE_CONFIG/dotfiles/active-selection.toml"; then
    pass "interactive and config set module bytes are identical"
else
    STATUS=1
    OUTPUT='module state bytes differ'
    fail "interactive and config set module bytes are identical"
fi

new_case unchanged
write_state "$CASE_CONFIG" "$PROFILE_BODY"
UNCHANGED_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
UNCHANGED_IDENTITY=$(identity_of "$UNCHANGED_PATH")
UNCHANGED_MODE=$(mode_of "$UNCHANGED_PATH")
UNCHANGED_CHECKSUM=$(cksum < "$UNCHANGED_PATH")
EVENTS=$(selection_events profile shell.minimal "" __NONE__)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "identical interactive state succeeds without confirmation" 0
check_contains "identical state reports unchanged" 'Local selection unchanged.'
check_not_contains "identical state never asks for confirmation" 'Save this local selection?'
check_not_contains "identical state never reports saved" 'Local selection saved.'
check_equal "no-change preserves state identity" "$(identity_of "$UNCHANGED_PATH")" "$UNCHANGED_IDENTITY"
check_equal "no-change preserves state mode" "$(mode_of "$UNCHANGED_PATH")" "$UNCHANGED_MODE"
check_equal "no-change preserves state bytes" "$(cksum < "$UNCHANGED_PATH")" "$UNCHANGED_CHECKSUM"
assert_no_debris "no-change preflight cleans its transient authority" "$CASE_CONFIG/dotfiles"

new_case existing-cancel
write_state "$CASE_CONFIG" "$STARSHIP_BODY"
EXISTING_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
EXISTING_IDENTITY=$(identity_of "$EXISTING_PATH")
EXISTING_MODE=$(mode_of "$EXISTING_PATH")
EXISTING_CHECKSUM=$(cksum < "$EXISTING_PATH")
EVENTS=$(selection_events profile shell.minimal "" no)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "cancellation with existing state succeeds" 0
check_equal "existing cancellation preserves identity" "$(identity_of "$EXISTING_PATH")" "$EXISTING_IDENTITY"
check_equal "existing cancellation preserves mode" "$(mode_of "$EXISTING_PATH")" "$EXISTING_MODE"
check_equal "existing cancellation preserves bytes" "$(cksum < "$EXISTING_PATH")" "$EXISTING_CHECKSUM"
assert_no_debris "existing cancellation cleans preflight material" "$CASE_CONFIG/dotfiles"

new_case invalid-current
write_state "$CASE_CONFIG" 'schema = 1

[selection]
profile = "shell.minimal"'
INVALID_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
INVALID_IDENTITY=$(identity_of "$INVALID_PATH")
INVALID_CHECKSUM=$(cksum < "$INVALID_PATH")
EVENTS=$(selection_events profile shell.minimal "" __NONE__)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "invalid current state fails before confirmation" 3
check_not_contains "invalid current state never asks for confirmation" 'Save this local selection?'
check_equal "invalid current state preserves identity" "$(identity_of "$INVALID_PATH")" "$INVALID_IDENTITY"
check_equal "invalid current state preserves bytes" "$(cksum < "$INVALID_PATH")" "$INVALID_CHECKSUM"
assert_no_debris "invalid-current preflight cleans transient material" "$CASE_CONFIG/dotfiles"

new_case active-lock
write_state "$CASE_CONFIG" "$STARSHIP_BODY"
mkdir "$CASE_CONFIG/dotfiles/active-selection.lock"
chmod 700 "$CASE_CONFIG/dotfiles/active-selection.lock"
LOCK_IDENTITY=$(identity_of "$CASE_CONFIG/dotfiles/active-selection.lock")
EVENTS=$(selection_events profile shell.minimal "" __NONE__)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "active writer lock fails before confirmation" 3
check_not_contains "active writer lock never asks for confirmation" 'Save this local selection?'
check_equal "pre-existing writer lock is preserved" "$(identity_of "$CASE_CONFIG/dotfiles/active-selection.lock")" "$LOCK_IDENTITY"

new_case confirmation-convergence
write_state "$CASE_CONFIG" "$STARSHIP_BODY"
STATE_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
BODY_FILE="$CASE_ROOT/profile-body"
IDENTITY_FILE="$CASE_ROOT/external-identity"
printf '%s\n' "$PROFILE_BODY" > "$BODY_FILE"
export DOTFILES_PTY_EVENT_HOOK=$STATE_HOOK
export DOTFILES_PTY_STATE_PATH=$STATE_PATH
export DOTFILES_PTY_STATE_BODY_FILE=$BODY_FILE
export DOTFILES_PTY_IDENTITY_FILE=$IDENTITY_FILE
EVENTS=$(selection_events profile shell.minimal "" yes hook)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
unset DOTFILES_PTY_EVENT_HOOK DOTFILES_PTY_STATE_PATH DOTFILES_PTY_STATE_BODY_FILE DOTFILES_PTY_IDENTITY_FILE
check_status "confirmation-time convergence succeeds" 0
check_contains "fresh writer reports confirmation-time convergence unchanged" 'Local selection unchanged.'
check_not_contains "confirmation-time convergence is not rewritten" 'Local selection saved.'
check_equal "fresh writer preserves the converged external object" "$(identity_of "$STATE_PATH")" "$(< "$IDENTITY_FILE")"
check_equal "confirmation-time convergence leaves exact proposal bytes" "$(< "$STATE_PATH")" "$PROFILE_BODY"
assert_no_debris "confirmation-time convergence leaves no owned debris" "$CASE_CONFIG/dotfiles"

new_case signal-hup
run_tty '[{"wait":"Base type (profile or modules):\n","signal":"HUP"}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "HUP while awaiting base returns 129" 129
check_path_absent "HUP while awaiting base creates no state" "$CASE_CONFIG"

new_case signal-int
run_tty '[{"wait":"Base type (profile or modules):\n","send":"profile"},{"wait":"Profile ID:\n","send":"shell.minimal"},{"wait":"Additional module IDs (comma-separated, empty for none):\n","signal":"INT"}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "INT while awaiting additions returns 130" 130
check_path_absent "INT while awaiting additions creates no state" "$CASE_CONFIG"

new_case signal-term
EVENTS='[{"wait":"Base type (profile or modules):\n","send":"profile"},{"wait":"Profile ID:\n","send":"shell.minimal"},{"wait":"Additional module IDs (comma-separated, empty for none):\n","send":""},{"wait":"Save this local selection? Type yes to continue:\n","signal":"TERM"}]'
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "TERM while awaiting confirmation returns 143" 143
check_path_absent "TERM while awaiting confirmation creates no state" "$CASE_CONFIG"

new_case explicit-consumers
EVENTS=$(selection_events profile shell.minimal "" yes)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "saved state for explicit-consumer checks succeeds" 0
for command in resolve prerequisite plan apply; do
    case "$command" in
        prerequisite) run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" prerequisite check --platform debian ;;
        *) run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" "$command" --platform debian ;;
    esac
    check_status "${command} still requires an explicit base" 2
done

if [ ! -s "$PROBE_LOG" ]; then
    pass "interactive selection invokes no provider, prerequisite, installer, network, pager, editor, privilege, render, plan, apply, or cache helper"
else
    STATUS=1
    OUTPUT=$(< "$PROBE_LOG")
    fail "interactive selection invokes no provider, prerequisite, installer, network, pager, editor, privilege, render, plan, apply, or cache helper"
fi

if awk '$NF != "execute-template" { bad = 1 } END { exit bad }' "$CHEZMOI_LOG"; then
    pass "interactive selection reaches only Chezmoi catalog template extraction"
else
    STATUS=1
    OUTPUT=$(< "$CHEZMOI_LOG")
    fail "interactive selection reaches only Chezmoi catalog template extraction"
fi

OUTPUT=$ALL_OUTPUT
check_not_contains "interactive output hides raw test roots" "$TEST_ROOT"
check_not_contains "interactive output hides the username" "$(id -un)"
check_not_contains "interactive output hides the hostname" "$(hostname)"

if rg -n 'schema = [^1]|schema must be [^1]' "$PROJECT_ROOT/.chezmoidata" "$PROJECT_ROOT/lib/config-state.sh" >/dev/null 2>&1; then
    STATUS=1
    OUTPUT='non-schema-1 active catalog or state implementation found'
    fail "interactive selection preserves schema 1"
else
    pass "interactive selection preserves schema 1"
fi

printf '%s config-interactive checks, %s failures\n' "$checks" "$failures"
[ "$failures" -eq 0 ]
