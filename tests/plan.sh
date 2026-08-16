#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
TEST_PARENT=${TMPDIR:-/tmp}
TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-plan-tests.XXXXXX")

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

# shellcheck source=../bin/dotfiles
source "${PROJECT_ROOT}/bin/dotfiles"
# shellcheck source=../lib/render.sh
source "${PROJECT_ROOT}/lib/render.sh"

REAL_CHEZMOI=$(command -v chezmoi)
RENDER_PROBE="${PROJECT_ROOT}/tests/helpers/chezmoi-render-probe.sh"
PLAN_PROBE="${PROJECT_ROOT}/tests/helpers/chezmoi-plan-probe.sh"
PROBE_BIN="${TEST_ROOT}/probe-bin"
PROBE_LOG="${TEST_ROOT}/external-invocations.log"
PLAN_INVOCATION_LOG="${TEST_ROOT}/plan-invocations.log"
PRIVATE_PATH_LOG="${TEST_ROOT}/private-paths.log"
PRIVATE_MODE_LOG="${TEST_ROOT}/private-modes.log"
STATE_MODE_LOG="${TEST_ROOT}/state-modes.log"
CONTEXT_PATH_LOG="${TEST_ROOT}/context-paths.log"
CONTEXT_MODE_LOG="${TEST_ROOT}/context-modes.log"
CONTEXT_SUMMARY_LOG="${TEST_ROOT}/context-summary.log"
ARTIFACT_ROOT="${TEST_ROOT}/share-root"
ARTIFACT_DIRECTORY="${ARTIFACT_ROOT}/zsh-autosuggestions"
ARTIFACT_LINK="${ARTIFACT_DIRECTORY}/zsh-autosuggestions.zsh"
ARTIFACT_TARGET="${ARTIFACT_DIRECTORY}/canonical-plugin.zsh"
ARTIFACT_ALTERNATE="${ARTIFACT_DIRECTORY}/alternate-plugin.zsh"

mkdir -p "$PROBE_BIN" "${TEST_ROOT}/homes" "${TEST_ROOT}/desired" "${TEST_ROOT}/tmp"
for probe in brew mise apt apt-get dnf yum pacman apk installer zsh starship less more bat delta diff code vim vi nano open xdg-open op bw pass gopass keepassxc-cli vault; do
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
export DOTFILES_EXPECTED_SOURCE_HOME="${PROJECT_ROOT}/home"
export DOTFILES_ALLOWED_TEST_ROOT="$TEST_ROOT"
export DOTFILES_PROBE_LOG="$PROBE_LOG"
export DOTFILES_PLAN_INVOCATION_LOG="$PLAN_INVOCATION_LOG"
export DOTFILES_PLAN_PRIVATE_PATH_LOG="$PRIVATE_PATH_LOG"
export DOTFILES_PLAN_PRIVATE_MODE_LOG="$PRIVATE_MODE_LOG"
export DOTFILES_PLAN_STATE_MODE_LOG="$STATE_MODE_LOG"
export DOTFILES_CONTEXT_PATH_LOG="$CONTEXT_PATH_LOG"
export DOTFILES_CONTEXT_MODE_LOG="$CONTEXT_MODE_LOG"
export DOTFILES_CONTEXT_SUMMARY_LOG="$CONTEXT_SUMMARY_LOG"
export DOTFILES_SHARE_ROOTS="$ARTIFACT_ROOT"
export DOTFILES_CHEZMOI_PROBE_MODE=delegate
export DOTFILES_PLAN_PROBE_MODE=delegate
export DOTFILES_RETARGET_LINK=
export DOTFILES_RETARGET_TARGET=
export PATH="${PROBE_BIN}:/usr/bin:/bin"
export TMPDIR="${TEST_ROOT}/tmp"
export PAGER="${PROBE_BIN}/less"
export GIT_PAGER="${PROBE_BIN}/less"
export CHEZMOI_PAGER="${PROBE_BIN}/less"

SOURCE_DIR=$PROJECT_ROOT
CHEZMOI_BIN=$REAL_CHEZMOI

failures=0
checks=0
OUTPUT=
STATUS=0
HOME_UNCHANGED=0
INVOCATIONS_BEFORE=0
INVOCATIONS_AFTER=0

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
    case "$OUTPUT" in
        *"$local_text"*) pass "$local_name" ;;
        *) STATUS=1; fail "$local_name" ;;
    esac
}

check_no_partial_plan() {
    local local_name=$1
    case "$OUTPUT" in
        *'Prerequisites: satisfied'*|*'Plan: '*|*'No changes.'*) STATUS=1; fail "$local_name" ;;
        *) pass "$local_name" ;;
    esac
}

line_count() {
    if [ -f "$1" ]; then
        wc -l < "$1" | tr -d ' '
    else
        printf '0\n'
    fi
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

home_snapshot() {
    (
        CDPATH= cd -- "$1" || exit 1
        find . -print | LC_ALL=C sort
        find . -type f -exec cksum {} \; | LC_ALL=C sort
        find . -type l -print -exec readlink {} \; | LC_ALL=C sort
    )
}

run_plan() {
    local local_home=$1
    local local_expected_targets=$2
    local local_before=
    local local_after=
    shift 2

    export DOTFILES_EXPECTED_PLAN_TARGETS=$local_expected_targets
    INVOCATIONS_BEFORE=$(line_count "$PLAN_INVOCATION_LOG")
    local_before=$(home_snapshot "$local_home")
    OUTPUT=$(HOME="$local_home" "${PROJECT_ROOT}/bin/dotfiles" plan "$@" 2>&1)
    STATUS=$?
    local_after=$(home_snapshot "$local_home")
    INVOCATIONS_AFTER=$(line_count "$PLAN_INVOCATION_LOG")
    if [ "$local_before" = "$local_after" ]; then HOME_UNCHANGED=1; else HOME_UNCHANGED=0; fi
}

check_run_safety() {
    local local_name=$1
    if [ "$HOME_UNCHANGED" -eq 1 ]; then
        pass "${local_name} leaves HOME byte-stable"
    else
        fail "${local_name} leaves HOME byte-stable"
    fi
    case "$OUTPUT" in
        *"$TEST_ROOT"*|*"$(id -un)"*|*"$(hostname)"*|*'must-not-be-read-or-printed'*)
            fail "${local_name} keeps private paths and identity out of output"
            ;;
        *) pass "${local_name} keeps private paths and identity out of output" ;;
    esac
}

expect_exact_plan() {
    local local_name=$1
    local local_home=$2
    local local_targets=$3
    local local_expected=$4
    shift 4
    run_plan "$local_home" "$local_targets" "$@"
    check_equal "${local_name} status" "$STATUS" 0
    check_equal "${local_name} output" "$OUTPUT" "$local_expected"
    check_run_safety "$local_name"
}

expect_failure() {
    local local_name=$1
    local local_expected_status=$2
    local local_home=$3
    local local_targets=$4
    shift 4
    run_plan "$local_home" "$local_targets" "$@"
    check_equal "${local_name} status" "$STATUS" "$local_expected_status"
    check_no_partial_plan "${local_name} produces no partial plan"
    check_run_safety "$local_name"
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
    if ! HOME="$local_home" dotfiles_render_selection "$local_output" "$local_profile" "$local_modules" "$local_additional" "$local_platform" >/dev/null 2>&1; then
        printf 'error: failed to prepare desired fixture %s\n' "$local_name" >&2
        exit 1
    fi
    printf '%s\n' "$local_output"
}

copy_target() {
    local local_source_root=$1
    local local_home=$2
    local local_target=$3
    mkdir -p "$(dirname -- "$local_home/$local_target")"
    cp -- "$local_source_root/$local_target" "$local_home/$local_target"
}

expected_step() {
    local local_platform=$1
    local local_action=$2
    local local_module=$3
    local local_source=$4
    local local_target=$5
    printf 'Prerequisites: satisfied\nPlan: 1 configuration change for %s\n\n1. %s %s chezmoi:target:%s\n   source: %s\n   network: no; privilege: none' \
        "$local_platform" "$local_action" "$local_module" "$local_target" "$local_source"
}

reset_artifact
zsh_targets=.zshrc
starship_targets=.config/starship.toml
autosuggestions_targets=$(printf '%s\n' '.config/zsh/autosuggestions.zsh' '.zshrc')
zsh_starship_targets=$(printf '%s\n' '.config/starship.toml' '.zshrc')
profile_targets=$(printf '%s\n' '.config/starship.toml' '.config/zsh/autosuggestions.zsh' '.zshrc')

for platform in macos debian; do
    home=$(new_home "${platform}-zsh-create")
    expected=$(expected_step "$platform" create shell.zsh home/dot_zshrc.tmpl .zshrc)
    expect_exact_plan "${platform} Zsh create" "$home" "$zsh_targets" "$expected" --modules shell.zsh --platform "$platform"

    home=$(new_home "${platform}-zsh-update")
    printf 'private destination contents must not be printed\n' > "$home/.zshrc"
    expected=$(expected_step "$platform" update shell.zsh home/dot_zshrc.tmpl .zshrc)
    expect_exact_plan "${platform} Zsh update" "$home" "$zsh_targets" "$expected" --modules shell.zsh --platform "$platform"

    home=$(new_home "${platform}-zsh-identical")
    desired=$(render_desired "${platform}-zsh" "$home" "" shell.zsh "" "$platform")
    copy_target "$desired" "$home" .zshrc
    expect_exact_plan "${platform} Zsh no-change" "$home" "$zsh_targets" 'No changes.' --modules shell.zsh --platform "$platform"

    home=$(new_home "${platform}-starship-create")
    ln -s /dev/null "$home/.zshrc"
    expected=$(expected_step "$platform" create prompt.starship home/dot_config/starship.toml .config/starship.toml)
    expect_exact_plan "${platform} Starship-only create" "$home" "$starship_targets" "$expected" --modules prompt.starship --platform "$platform"

    home=$(new_home "${platform}-mixed-modules")
    printf 'different Zsh state\n' > "$home/.zshrc"
    expected=$(printf 'Prerequisites: satisfied\nPlan: 2 configuration changes for %s\n\n1. create prompt.starship chezmoi:target:.config/starship.toml\n   source: home/dot_config/starship.toml\n   network: no; privilege: none\n\n2. update shell.zsh chezmoi:target:.zshrc\n   source: home/dot_zshrc.tmpl\n   network: no; privilege: none' "$platform")
    expect_exact_plan "${platform} mixed direct modules" "$home" "$zsh_starship_targets" "$expected" --modules shell.zsh,prompt.starship --platform "$platform"

    home=$(new_home "${platform}-autosuggestions")
    expected=$(printf 'Prerequisites: satisfied\nPlan: 2 configuration changes for %s\n\n1. create shell.zsh.autosuggestions chezmoi:target:.config/zsh/autosuggestions.zsh\n   source: home/dot_config/zsh/autosuggestions.zsh\n   network: no; privilege: none\n\n2. create shell.zsh chezmoi:target:.zshrc\n   source: home/dot_zshrc.tmpl\n   network: no; privilege: none' "$platform")
    expect_exact_plan "${platform} autosuggestions dependency plan" "$home" "$autosuggestions_targets" "$expected" --modules shell.zsh.autosuggestions --platform "$platform"

    home=$(new_home "${platform}-profile-create")
    expected=$(printf 'Prerequisites: satisfied\nPlan: 3 configuration changes for %s\n\n1. create prompt.starship chezmoi:target:.config/starship.toml\n   source: home/dot_config/starship.toml\n   network: no; privilege: none\n\n2. create shell.zsh.autosuggestions chezmoi:target:.config/zsh/autosuggestions.zsh\n   source: home/dot_config/zsh/autosuggestions.zsh\n   network: no; privilege: none\n\n3. create shell.zsh chezmoi:target:.zshrc\n   source: home/dot_zshrc.tmpl\n   network: no; privilege: none' "$platform")
    expect_exact_plan "${platform} profile all-create" "$home" "$profile_targets" "$expected" --profile shell.minimal --platform "$platform"

    home=$(new_home "${platform}-profile-mixed")
    desired=$(render_desired "${platform}-profile" "$home" shell.minimal "" "" "$platform")
    copy_target "$desired" "$home" .zshrc
    mkdir -p "$home/.config/zsh"
    printf 'different autosuggestions state\n' > "$home/.config/zsh/autosuggestions.zsh"
    expected=$(printf 'Prerequisites: satisfied\nPlan: 2 configuration changes for %s\n\n1. create prompt.starship chezmoi:target:.config/starship.toml\n   source: home/dot_config/starship.toml\n   network: no; privilege: none\n\n2. update shell.zsh.autosuggestions chezmoi:target:.config/zsh/autosuggestions.zsh\n   source: home/dot_config/zsh/autosuggestions.zsh\n   network: no; privilege: none' "$platform")
    expect_exact_plan "${platform} profile mixed subset" "$home" "$profile_targets" "$expected" --profile shell.minimal --platform "$platform"

    home=$(new_home "${platform}-profile-identical")
    for target in .config/starship.toml .config/zsh/autosuggestions.zsh .zshrc; do copy_target "$desired" "$home" "$target"; done
    expect_exact_plan "${platform} profile no-change" "$home" "$profile_targets" 'No changes.' --profile shell.minimal --platform "$platform"

    home=$(new_home "${platform}-narrower")
    for target in .config/starship.toml .config/zsh/autosuggestions.zsh .zshrc; do copy_target "$desired" "$home" "$target"; done
    expected=$(expected_step "$platform" update shell.zsh home/dot_zshrc.tmpl .zshrc)
    expect_exact_plan "${platform} narrower Zsh after broad state" "$home" "$zsh_targets" "$expected" --modules shell.zsh --platform "$platform"
done

home=$(new_home add-selection)
expected=$(printf 'Prerequisites: satisfied\nPlan: 2 configuration changes for debian\n\n1. create prompt.starship chezmoi:target:.config/starship.toml\n   source: home/dot_config/starship.toml\n   network: no; privilege: none\n\n2. create shell.zsh chezmoi:target:.zshrc\n   source: home/dot_zshrc.tmpl\n   network: no; privilege: none')
expect_exact_plan '--add shares resolver semantics' "$home" "$zsh_starship_targets" "$expected" --modules shell.zsh --add prompt.starship --platform debian

detected_platform=$(detect_platform)
home=$(new_home implicit-platform)
expected=$(expected_step "$detected_platform" create shell.zsh home/dot_zshrc.tmpl .zshrc)
expect_exact_plan 'implicit platform uses shared detector' "$home" "$zsh_targets" "$expected" --modules shell.zsh

home=$(new_home deterministic-repeat)
run_plan "$home" "$profile_targets" --profile shell.minimal --platform debian
first_output=$OUTPUT
first_status=$STATUS
run_plan "$home" "$profile_targets" --profile shell.minimal --platform debian
check_equal 'repeated identical plan status is stable' "$STATUS" "$first_status"
check_equal 'repeated identical plan output is byte-stable' "$OUTPUT" "$first_output"
check_run_safety 'repeated identical plan'

for arguments in \
    '--profile shell.minimal --modules shell.zsh' \
    '--modules shell.zsh --modules shell.zsh' \
    '--modules shell.zsh --platform debian --platform debian' \
    '--modules shell.zsh --unknown value' \
    '--modules' \
    '--platform debian' \
    '--modules shell.zsh --destination /tmp'; do
    home=$(new_home "usage-${checks}")
    # Intentional word splitting supplies the static invalid-argument fixtures.
    # shellcheck disable=SC2086
    expect_failure "usage rejection: ${arguments}" 2 "$home" "$zsh_targets" $arguments
done

home=$(new_home private-invalid-module)
expect_failure 'invalid private module input' 3 "$home" "$zsh_targets" --modules "$TEST_ROOT" --platform debian

home=$(new_home private-invalid-platform)
expect_failure 'invalid private platform input' 3 "$home" "$zsh_targets" --modules shell.zsh --platform "$TEST_ROOT"

home=$(new_home missing-command)
chmod -x "$PROBE_BIN/starship"
expect_failure 'missing selected command' 5 "$home" "$starship_targets" --modules prompt.starship --platform debian
check_contains 'missing command error names module, kind, and identifier' 'module prompt.starship requires command starship on debian'
check_equal 'missing command fails before Chezmoi status' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
chmod +x "$PROBE_BIN/starship"

home=$(new_home missing-artifact)
rm -f -- "$ARTIFACT_LINK"
expect_failure 'missing selected artifact' 5 "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform macos
check_contains 'missing artifact error names module, kind, and locator' 'module shell.zsh.autosuggestions requires artifact share:zsh-autosuggestions/zsh-autosuggestions.zsh on macos'
check_equal 'missing artifact fails before Chezmoi status' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"

for mode in retarget-contained break typechange retarget; do
    reset_artifact
    export DOTFILES_CHEZMOI_PROBE_MODE=$mode
    export DOTFILES_RETARGET_LINK=$ARTIFACT_LINK
    export DOTFILES_RETARGET_TARGET=$ARTIFACT_ALTERNATE
    home=$(new_home "artifact-${mode}")
    case "$mode" in retarget-contained) expected_status=3 ;; *) expected_status=5 ;; esac
    expect_failure "artifact ${mode} before comparison" "$expected_status" "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform debian
    check_equal "artifact ${mode} fails before Chezmoi status" "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
done
export DOTFILES_CHEZMOI_PROBE_MODE=delegate
export DOTFILES_RETARGET_LINK=
export DOTFILES_RETARGET_TARGET=
reset_artifact

for mode in malformed unselected duplicate deletion wrong-effect fail; do
    export DOTFILES_PLAN_PROBE_MODE=$mode
    home=$(new_home "comparison-${mode}")
    case "$mode" in fail) expected_status=5 ;; *) expected_status=3 ;; esac
    expect_failure "comparison ${mode} fails closed" "$expected_status" "$home" "$zsh_targets" --modules shell.zsh --platform debian
done

export DOTFILES_PLAN_PROBE_MODE=out-of-order
home=$(new_home comparison-out-of-order)
expect_failure 'out-of-order comparison fails closed' 3 "$home" "$profile_targets" --profile shell.minimal --platform macos

export DOTFILES_PLAN_PROBE_MODE=term
home=$(new_home comparison-interruption)
expect_failure 'handled comparison interruption' 143 "$home" "$zsh_targets" --modules shell.zsh --platform debian
export DOTFILES_PLAN_PROBE_MODE=delegate

saved_plan_bin=$DOTFILES_PLAN_CHEZMOI_BIN
export DOTFILES_PLAN_CHEZMOI_BIN="${TEST_ROOT}/missing-chezmoi"
home=$(new_home missing-comparison-engine)
expect_failure 'missing Chezmoi comparison engine' 4 "$home" "$zsh_targets" --modules shell.zsh --platform debian
export DOTFILES_PLAN_CHEZMOI_BIN=$saved_plan_bin

export DOTFILES_CHEZMOI_PROBE_MODE=fail
home=$(new_home renderer-failure)
expect_failure 'renderer failure' 4 "$home" "$zsh_targets" --modules shell.zsh --platform macos
export DOTFILES_CHEZMOI_PROBE_MODE=delegate

home=$(new_home symlink-target)
ln -s /dev/null "$home/.zshrc"
expect_failure 'selected symlink target' 3 "$home" "$zsh_targets" --modules shell.zsh --platform debian
check_equal 'selected symlink fails before Chezmoi status' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"

home=$(new_home directory-target)
mkdir "$home/.zshrc"
expect_failure 'selected directory target' 3 "$home" "$zsh_targets" --modules shell.zsh --platform debian

home=$(new_home fifo-target)
mkfifo "$home/.zshrc"
expect_failure 'selected FIFO target' 3 "$home" "$zsh_targets" --modules shell.zsh --platform debian

home=$(new_home symlink-parent)
ln -s /dev/null "$home/.config/zsh"
expect_failure 'selected symlink parent' 3 "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform macos

real_home=$(new_home symlink-home-real)
home_link="${TEST_ROOT}/homes/symlink-home"
ln -s "$real_home" "$home_link"
expect_failure 'symlink HOME' 3 "$home_link" "$zsh_targets" --modules shell.zsh --platform debian

OUTPUT=$(HOME=relative-home "${PROJECT_ROOT}/bin/dotfiles" plan --modules shell.zsh --platform debian 2>&1)
STATUS=$?
check_equal 'relative HOME status' "$STATUS" 3
check_no_partial_plan 'relative HOME produces no partial plan'

help_output=$("${PROJECT_ROOT}/bin/dotfiles" help)
case "$help_output" in
    *'dotfiles plan (--profile <profile-id> | --modules <id,id>) [--add <id,id>] [--platform macos|debian]'*)
        pass 'built-in help lists the exact plan syntax'
        ;;
    *) STATUS=1; OUTPUT=$help_output; fail 'built-in help lists the exact plan syntax' ;;
esac
case "$help_output" in *'dotfiles apply'*) pass 'built-in help lists apply after plan' ;; *) STATUS=1; OUTPUT=$help_output; fail 'built-in help lists apply after plan' ;; esac

cleanup_ok=1
for path_log in "$PRIVATE_PATH_LOG" "$CONTEXT_PATH_LOG"; do
    [ -f "$path_log" ] || continue
    while IFS= read -r private_path; do
        [ -n "$private_path" ] || continue
        [ ! -e "$private_path" ] || cleanup_ok=0
    done < "$path_log"
done
if [ "$cleanup_ok" -eq 1 ]; then pass 'all observed plan and render private paths are removed'; else STATUS=1; OUTPUT='private path remains'; fail 'all observed plan and render private paths are removed'; fi

if [ -f "$PRIVATE_MODE_LOG" ] && ! grep -Ev '^600 700 700 700 600 600 600$' "$PRIVATE_MODE_LOG" | grep -q .; then
    pass 'plan context, cache, and captured files use restrictive modes'
else
    STATUS=1; OUTPUT='unexpected plan private mode'; fail 'plan context, cache, and captured files use restrictive modes'
fi
if [ -f "$CONTEXT_MODE_LOG" ] && ! grep -Ev '^600 700$' "$CONTEXT_MODE_LOG" | grep -q .; then
    pass 'renderer contexts remain mode-restricted during planning'
else
    STATUS=1; OUTPUT='unexpected render context mode'; fail 'renderer contexts remain mode-restricted during planning'
fi
if [ -f "$STATE_MODE_LOG" ] && ! grep -Ev '^state (600|absent)$' "$STATE_MODE_LOG" | grep -q .; then
    pass 'isolated Chezmoi state uses a restrictive mode'
else
    STATUS=1; OUTPUT='missing or unsafe Chezmoi state mode'; fail 'isolated Chezmoi state uses a restrictive mode'
fi

if [ ! -e "$PROBE_LOG" ]; then
    pass 'planning invokes no provider, prerequisite, artifact, pager, editor, or external diff'
else
    STATUS=97
    OUTPUT=$(<"$PROBE_LOG")
    fail 'planning invokes no provider, prerequisite, artifact, pager, editor, or external diff'
fi

if [ "$failures" -ne 0 ]; then
    printf '%s of %s plan checks failed\n' "$failures" "$checks" >&2
    exit 1
fi

printf '%s plan checks passed\n' "$checks"
