#!/usr/bin/env bash

config_state_allocate_root() {
    TEST_PARENT=${TMPDIR:-/tmp}
    TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
    TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-config-state-tests.XXXXXX")
}

config_state_initialize() {
    CLI="${PROJECT_ROOT}/bin/dotfiles"
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
stage_fixture() {
    local name=$1
    local target="${TEST_ROOT}/fixture-${name}/.chezmoidata"
    mkdir -p "$target"
    cp -R "${PROJECT_ROOT}/tests/fixtures/${name}/catalog/." "$target/"
    printf '%s\n' "${TEST_ROOT}/fixture-${name}"
}
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
hook_hold_lock() {
    local attempt
    for attempt in {1..500}; do
        [ -e "$DOTFILES_CONFIG_TEST_RELEASE_FILE" ] && return 0
        sleep 0.01
    done
    return 1
}
