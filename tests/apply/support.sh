#!/usr/bin/env bash

apply_allocate_root() {
    TEST_PARENT=${TMPDIR:-/tmp}
    TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
    TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-apply-tests.XXXXXX")
}

apply_initialize() {
    # shellcheck source=../bin/dotfiles
    source "${PROJECT_ROOT}/bin/dotfiles"
    # shellcheck source=../lib/render.sh
    source "${PROJECT_ROOT}/lib/render.sh"

    REAL_CHEZMOI=$(command -v chezmoi)
    RENDER_PROBE="${PROJECT_ROOT}/tests/helpers/chezmoi-render-probe.sh"
    PLAN_PROBE="${PROJECT_ROOT}/tests/helpers/chezmoi-plan-probe.sh"
    APPLY_PROBE="${PROJECT_ROOT}/tests/helpers/chezmoi-apply-probe.sh"
    PTY_CONFIRM="${PROJECT_ROOT}/tests/helpers/pty-confirm.py"
    CONFIRM_HOOK="${PROJECT_ROOT}/tests/helpers/apply-confirmation-hook.sh"
    PROBE_BIN="${TEST_ROOT}/probe-bin"
    PROBE_LOG="${TEST_ROOT}/external-invocations.log"
    PLAN_INVOCATION_LOG="${TEST_ROOT}/plan-invocations.log"
    APPLY_INVOCATION_LOG="${TEST_ROOT}/apply-invocations.log"
    PRIVATE_PATH_LOG="${TEST_ROOT}/private-paths.log"
    PRIVATE_MODE_LOG="${TEST_ROOT}/private-modes.log"
    STATE_MODE_LOG="${TEST_ROOT}/state-modes.log"
    APPLY_PRIVATE_PATH_LOG="${TEST_ROOT}/apply-private-paths.log"
    APPLY_PRIVATE_MODE_LOG="${TEST_ROOT}/apply-private-modes.log"
    CONTEXT_PATH_LOG="${TEST_ROOT}/context-paths.log"
    CONTEXT_MODE_LOG="${TEST_ROOT}/context-modes.log"
    CONTEXT_SUMMARY_LOG="${TEST_ROOT}/context-summary.log"
    CONFIRM_PRIVATE_MODE_LOG="${TEST_ROOT}/confirmation-private-modes.log"
    ARTIFACT_ROOT="${TEST_ROOT}/share-root"
    ARTIFACT_DIRECTORY="${ARTIFACT_ROOT}/zsh-autosuggestions"
    ARTIFACT_LINK="${ARTIFACT_DIRECTORY}/zsh-autosuggestions.zsh"
    ARTIFACT_TARGET="${ARTIFACT_DIRECTORY}/canonical-plugin.zsh"
    ARTIFACT_ALTERNATE="${ARTIFACT_DIRECTORY}/alternate-plugin.zsh"

    mkdir -p "$PROBE_BIN" "${TEST_ROOT}/homes" "${TEST_ROOT}/desired" "${TEST_ROOT}/tmp"
    for probe in brew mise apt apt-get dnf yum pacman apk installer zsh starship less more bat delta diff code vim vi nano open xdg-open op bw pass gopass keepassxc-cli vault sudo doas curl wget git age; do
        printf '%s\n' \
            '#!/bin/sh' \
            'printf "%s\n" "$0 $*" >> "$DOTFILES_PROBE_LOG"' \
            'exit 97' > "${PROBE_BIN}/${probe}"
        chmod +x "${PROBE_BIN}/${probe}"
    done

    export DOTFILES_REAL_CHEZMOI="$REAL_CHEZMOI"
    export DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI"
    export DOTFILES_RENDER_CHEZMOI_BIN="$RENDER_PROBE"
    export DOTFILES_PLAN_CHEZMOI_BIN="$PLAN_PROBE"
    export DOTFILES_APPLY_CHEZMOI_BIN="$APPLY_PROBE"
    export DOTFILES_EXPECTED_SOURCE_HOME="${PROJECT_ROOT}/home"
    export DOTFILES_ALLOWED_TEST_ROOT="$TEST_ROOT"
    export DOTFILES_PROBE_LOG="$PROBE_LOG"
    export DOTFILES_PLAN_INVOCATION_LOG="$PLAN_INVOCATION_LOG"
    export DOTFILES_APPLY_INVOCATION_LOG="$APPLY_INVOCATION_LOG"
    export DOTFILES_PLAN_PRIVATE_PATH_LOG="$PRIVATE_PATH_LOG"
    export DOTFILES_PLAN_PRIVATE_MODE_LOG="$PRIVATE_MODE_LOG"
    export DOTFILES_PLAN_STATE_MODE_LOG="$STATE_MODE_LOG"
    export DOTFILES_APPLY_PRIVATE_PATH_LOG="$APPLY_PRIVATE_PATH_LOG"
    export DOTFILES_APPLY_PRIVATE_MODE_LOG="$APPLY_PRIVATE_MODE_LOG"
    export DOTFILES_CONTEXT_PATH_LOG="$CONTEXT_PATH_LOG"
    export DOTFILES_CONTEXT_MODE_LOG="$CONTEXT_MODE_LOG"
    export DOTFILES_CONTEXT_SUMMARY_LOG="$CONTEXT_SUMMARY_LOG"
    export DOTFILES_SHARE_ROOTS="$ARTIFACT_ROOT"
    export DOTFILES_CHEZMOI_PROBE_MODE=delegate
    export DOTFILES_PLAN_PROBE_MODE=delegate
    export DOTFILES_APPLY_PROBE_MODE=delegate
    export DOTFILES_PLAN_PROBE_AFTER_STATUS_MODE=
    export DOTFILES_RETARGET_LINK=
    export DOTFILES_RETARGET_TARGET=
    export DOTFILES_APPLY_PROBE_TARGET=
    export DOTFILES_APPLY_PROBE_NEXT_TARGET=
    export DOTFILES_PTY_CONFIRM_HOOK=
    export DOTFILES_CONFIRM_HOOK_MODE=
    export DOTFILES_CONFIRM_HOOK_TARGET=
    export DOTFILES_CONFIRM_HOOK_LOG="$CONFIRM_PRIVATE_MODE_LOG"
    export PATH="${PROBE_BIN}:/usr/bin:/bin"
    export TMPDIR="${TEST_ROOT}/tmp"
    export PAGER="${PROBE_BIN}/less"
    export GIT_PAGER="${PROBE_BIN}/less"
    export CHEZMOI_PAGER="${PROBE_BIN}/less"
    export PYTHONDONTWRITEBYTECODE=1

    SOURCE_DIR=$PROJECT_ROOT
    CHEZMOI_BIN=$REAL_CHEZMOI

    failures=0
    checks=0
    OUTPUT=
    STATUS=0
    INVOCATIONS_BEFORE=0
    INVOCATIONS_AFTER=0
    HOME_BEFORE=
    HOME_AFTER=
    reset_artifact
    zsh_targets=.zshrc
    starship_targets=.config/starship.toml
    autosuggestions_targets=$(printf '%s\n' '.config/zsh/autosuggestions.zsh' '.zshrc')
    profile_targets=$(printf '%s\n' '.config/starship.toml' '.config/zsh/autosuggestions.zsh' '.zshrc')
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

check_equal() {
    local local_name=$1
    local local_actual=$2
    local local_expected=$3
    if [ "$local_actual" = "$local_expected" ]; then
        pass "$local_name"
    else
        STATUS=1
        OUTPUT="expected ${local_expected}; got ${local_actual}"
        fail "$local_name"
    fi
}

check_contains() {
    local local_name=$1
    local local_text=$2
    case "$OUTPUT" in *"$local_text"*) pass "$local_name" ;; *) STATUS=1; fail "$local_name" ;; esac
}

check_not_contains() {
    local local_name=$1
    local local_text=$2
    case "$OUTPUT" in *"$local_text"*) STATUS=1; fail "$local_name" ;; *) pass "$local_name" ;; esac
}

line_count() {
    if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else printf '0\n'; fi
}

home_snapshot() {
    (
        CDPATH= cd -- "$1" || exit 1
        find . -print | LC_ALL=C sort
        find . -type f -exec cksum {} \; | LC_ALL=C sort
        find . -type l -print -exec readlink {} \; | LC_ALL=C sort
    )
}

reset_artifact() {
    rm -rf -- "$ARTIFACT_DIRECTORY"
    mkdir -p "$ARTIFACT_DIRECTORY"
    printf '%s\n' \
        '#!/bin/sh' \
        'printf "artifact invoked\n" >> "$DOTFILES_PROBE_LOG"' \
        'exit 97' > "$ARTIFACT_TARGET"
    printf 'alternate artifact\n' > "$ARTIFACT_ALTERNATE"
    chmod +x "$ARTIFACT_TARGET" "$ARTIFACT_ALTERNATE"
    ln -s "$(basename -- "$ARTIFACT_TARGET")" "$ARTIFACT_LINK"
}

new_home() {
    local local_name=$1
    local local_home="${TEST_ROOT}/homes/${local_name}"
    mkdir -p "$local_home/.config/chezmoi"
    printf '%s\n' \
        '[diff]' \
        "command = \"${PROBE_BIN}/diff\"" \
        '[data.private]' \
        'machine_identity = "must-not-be-read-or-printed"' > "$local_home/.config/chezmoi/chezmoi.toml"
    printf '%s\n' "$local_home"
}

render_desired() {
    local local_name=$1
    local local_home=$2
    local local_profile=$3
    local local_modules=$4
    local local_additional=$5
    local local_platform=$6
    local local_output="${TEST_ROOT}/desired/${local_name}"
    mkdir "$local_output"
    HOME="$local_home" dotfiles_render_selection "$local_output" "$local_profile" "$local_modules" \
        "$local_additional" "$local_platform" >/dev/null 2>&1 || return 1
    printf '%s\n' "$local_output"
}

copy_target() {
    mkdir -p "$(dirname -- "$2/$3")"
    cp -- "$1/$3" "$2/$3"
}

run_apply() {
    local local_home=$1
    local local_targets=$2
    shift 2
    export DOTFILES_EXPECTED_PLAN_TARGETS=$local_targets
    export DOTFILES_EXPECTED_APPLY_TARGETS=$local_targets
    INVOCATIONS_BEFORE=$(line_count "$APPLY_INVOCATION_LOG")
    HOME_BEFORE=$(home_snapshot "$local_home")
    OUTPUT=$(HOME="$local_home" "${PROJECT_ROOT}/bin/dotfiles" apply "$@" 2>&1)
    STATUS=$?
    HOME_AFTER=$(home_snapshot "$local_home")
    INVOCATIONS_AFTER=$(line_count "$APPLY_INVOCATION_LOG")
}

run_apply_tty() {
    local local_answer=$1
    local local_home=$2
    local local_targets=$3
    shift 3
    export DOTFILES_EXPECTED_PLAN_TARGETS=$local_targets
    export DOTFILES_EXPECTED_APPLY_TARGETS=$local_targets
    INVOCATIONS_BEFORE=$(line_count "$APPLY_INVOCATION_LOG")
    HOME_BEFORE=$(home_snapshot "$local_home")
    OUTPUT=$(HOME="$local_home" "$PTY_CONFIRM" "$local_answer" "${PROJECT_ROOT}/bin/dotfiles" apply "$@" 2>&1)
    STATUS=$?
    HOME_AFTER=$(home_snapshot "$local_home")
    INVOCATIONS_AFTER=$(line_count "$APPLY_INVOCATION_LOG")
}

check_private_output() {
    local local_name=$1
    case "$OUTPUT" in
        *"$TEST_ROOT"*|*"$(id -un)"*|*"$(hostname)"*|*'must-not-be-read-or-printed'*) fail "$local_name" ;;
        *) pass "$local_name" ;;
    esac
}

check_zero_mutation() {
    local local_name=$1
    if [ "$HOME_BEFORE" = "$HOME_AFTER" ] && [ "$INVOCATIONS_BEFORE" = "$INVOCATIONS_AFTER" ]; then
        pass "$local_name"
    else
        fail "$local_name"
    fi
}

expected_step() {
    printf 'Prerequisites: satisfied\nPlan: 1 configuration change for %s\n\n1. %s %s chezmoi:target:%s\n   source: %s\n   network: no; privilege: none' \
        "$1" "$2" "$3" "$5" "$4"
}
