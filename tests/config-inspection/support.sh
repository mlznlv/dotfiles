#!/usr/bin/env bash

config_inspection_initialize() {
    CLI="${PROJECT_ROOT}/bin/dotfiles"
    TEST_PARENT=${TMPDIR:-/tmp}
    TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
    TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-config-inspection-tests.XXXXXX")
    REAL_CHEZMOI=$(command -v chezmoi)
    PROBE_BIN="${TEST_ROOT}/probe-bin"
    PROBE_LOG="${TEST_ROOT}/external-invocations.log"
    mkdir -p "$PROBE_BIN" "${TEST_ROOT}/homes" "${TEST_ROOT}/roots" "${TEST_ROOT}/fixtures"
    
    for probe in brew mise apt apt-get dnf yum pacman apk installer zsh starship less more bat delta diff code vim vi nano open xdg-open op bw pass gopass keepassxc-cli vault sudo doas curl wget; do
        printf '%s\n' \
            '#!/bin/sh' \
            'printf "%s\n" "$0 $*" >> "$DOTFILES_INSPECTION_PROBE_LOG"' \
            'exit 97' > "${PROBE_BIN}/${probe}"
        chmod +x "${PROBE_BIN}/${probe}"
    done
    
    export DOTFILES_INSPECTION_PROBE_LOG=$PROBE_LOG
    export DOTFILES_CHEZMOI_BIN=$REAL_CHEZMOI
    export PATH="${PROBE_BIN}:/usr/bin:/bin"
    
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

MODULE_BODY='schema = 1

[selection]
modules = ["prompt.starship", "shell.zsh"]
additional_modules = ["shell.zsh.autosuggestions"]'

ADDITIONAL_BODY='schema = 1

[selection]
modules = ["shell.zsh"]
additional_modules = ["prompt.starship"]'

PROFILE_DEBIAN_OUTPUT='Selection source: local
Base: shell.minimal
Additional modules: none
Resolved modules for debian:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship'

PROFILE_MACOS_OUTPUT='Selection source: local
Base: shell.minimal
Additional modules: none
Resolved modules for macos:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship'

MODULE_MACOS_OUTPUT='Selection source: local
Base: prompt.starship,shell.zsh
Additional modules: shell.zsh.autosuggestions
Resolved modules for macos:
  prompt.starship
  shell.zsh
  shell.zsh.autosuggestions'
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

run_command() {
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    "$@" > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
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

run_cli_with_write_only_high_descriptor() {
    local root=$1
    local home=$2
    shift 2
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"
    local descriptor_file="${TEST_ROOT}/write-only-descriptor"
    local command_status

    : > "$descriptor_file"
    exec 254>>"$descriptor_file"
    XDG_CONFIG_HOME="$root" HOME="$home" main "$@" > "$stdout_file" 2> "$stderr_file"
    command_status=$?
    printf 'descriptor-preserved\n' >&254 2>> "$stderr_file"
    DESCRIPTOR_STATUS=$?
    exec 254>&-

    STATUS=$command_status
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
    DESCRIPTOR_OUTPUT=$(< "$descriptor_file")
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

write_state() {
    local root=$1
    local body=$2
    mkdir -p "$root/dotfiles"
    chmod 700 "$root/dotfiles"
    printf '%s\n' "$body" > "$root/dotfiles/active-selection.toml"
    chmod 600 "$root/dotfiles/active-selection.toml"
}

tree_snapshot() {
    local root=$1
    if [ ! -e "$root" ] && [ ! -L "$root" ]; then
        printf 'missing\n'
        return
    fi
    (
        CDPATH= cd -- "$root" || exit 1
        find . -print | LC_ALL=C sort
        find . -type f -exec cksum {} \; | LC_ALL=C sort
        find . -type l -print -exec readlink {} \; | LC_ALL=C sort
    )
}

state_snapshot() {
    local state="$1/dotfiles/active-selection.toml"
    local mtime
    local mode
    if [ ! -e "$state" ] && [ ! -L "$state" ]; then
        tree_snapshot "$1"
        return
    fi
    printf 'identity=%s\n' "$(dotfiles_config_stat_identity "$state" 2>/dev/null || printf unavailable)"
    mode=$(dotfiles_config_stat_mode "$state" 2>/dev/null || printf unavailable)
    printf 'mode=%s\n' "$mode"
    mtime=$(stat -c '%Y' "$state" 2>/dev/null) ||
        mtime=$(stat -f '%m' "$state" 2>/dev/null) || mtime=unavailable
    printf 'mtime=%s\n' "$mtime"
    [ ! -f "$state" ] || cksum "$state"
    tree_snapshot "$1"
}

stage_fixture() {
    local name=$1
    local target="${TEST_ROOT}/fixtures/${name}/.chezmoidata"
    mkdir -p "$target"
    cp -R "${PROJECT_ROOT}/tests/fixtures/${name}/catalog/." "$target/"
    printf '%s\n' "${TEST_ROOT}/fixtures/${name}"
}

assert_no_summary() {
    local name=$1
    if [ -z "$STDOUT" ] && [[ $OUTPUT != *'Selection source:'* ]] && \
       [[ $OUTPUT != *'Local selection file: healthy'* ]] && \
       [[ $OUTPUT != *'Composition for '* ]]; then
        pass "$name"
    else
        STATUS=1
        fail "$name"
    fi
}
invalid_doctor_case() {
    local name=$1
    local body=$2
    local root
    local home
    local before
    root=$(new_root "invalid-${checks}")
    home=$(new_home "invalid-${checks}")
    write_state "$root" "$body"
    before=$(state_snapshot "$root")
    run_cli "$root" "$home" config doctor --platform debian
    if [ "$STATUS" -eq 3 ] && [ -z "$STDOUT" ] && [ "$(state_snapshot "$root")" = "$before" ]; then
        pass "$name"
    else
        fail "$name"
    fi
}
fail_read_handle_open() {
    return 4
}
replace_after_first_read() {
    local replacement="${DOTFILES_CONFIG_STATE_PATH}.replacement"
    cp "$DOTFILES_CONFIG_STATE_PATH" "$replacement"
    chmod 600 "$replacement"
    mv -f "$replacement" "$DOTFILES_CONFIG_STATE_PATH"
}
change_after_first_read() {
    printf '\n' >> "$DOTFILES_CONFIG_STATE_PATH"
}
