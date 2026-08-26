#!/usr/bin/env bash

config_interactive_allocate_root() {
    TEST_PARENT=${TMPDIR:-/tmp}
    TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
    TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-config-interactive-tests.XXXXXX")
}

config_interactive_initialize() {
    CLI="${PROJECT_ROOT}/bin/dotfiles"
    PTY_HELPER="${PROJECT_ROOT}/tests/helpers/pty-interactive.py"
    STATE_HOOK="${PROJECT_ROOT}/tests/helpers/interactive-state-hook.sh"
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
}

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
stage_fixture() {
    local name=$1
    local target="${TEST_ROOT}/fixtures/${name}/.chezmoidata"
    mkdir -p "$target"
    cp -R "${PROJECT_ROOT}/tests/fixtures/${name}/catalog/." "$target/"
}
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
    "$@" </dev/null > "$stdout_file" 2> "$stderr_file"
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
