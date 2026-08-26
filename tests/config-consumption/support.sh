#!/usr/bin/env bash

config_consumption_initialize() {
    CLI="${PROJECT_ROOT}/bin/dotfiles"
    PTY_CONFIRM="${PROJECT_ROOT}/tests/helpers/pty-confirm.py"
    CONFIRM_HOOK="${PROJECT_ROOT}/tests/helpers/apply-confirmation-hook.sh"
    TEST_PARENT=${TMPDIR:-/tmp}
    TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
    TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-config-consumption-tests.XXXXXX")
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
    DRIFT_STATE=
}

cleanup() {
    rm -rf -- "$TEST_ROOT"
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
fail_read_handle_open() {
    return 4
}
