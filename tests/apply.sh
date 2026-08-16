#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
TEST_PARENT=${TMPDIR:-/tmp}
TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-apply-tests.XXXXXX")

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

reset_artifact
zsh_targets=.zshrc
starship_targets=.config/starship.toml
autosuggestions_targets=$(printf '%s\n' '.config/zsh/autosuggestions.zsh' '.zshrc')
profile_targets=$(printf '%s\n' '.config/starship.toml' '.config/zsh/autosuggestions.zsh' '.zshrc')

help_output=$("${PROJECT_ROOT}/bin/dotfiles" help)
case "$help_output" in
    *'dotfiles apply (--profile <profile-id> | --modules <id,id>) [--add <id,id>] [--platform macos|debian] [--yes]'*) pass 'help lists exact apply syntax' ;;
    *) STATUS=1; OUTPUT=$help_output; fail 'help lists exact apply syntax' ;;
esac

for arguments in \
    '--profile shell.minimal --modules shell.zsh --yes' \
    '--modules shell.zsh --modules shell.zsh --yes' \
    '--modules shell.zsh --add prompt.starship --add prompt.starship --yes' \
    '--modules shell.zsh --platform debian --platform debian --yes' \
    '--modules shell.zsh --yes --yes' \
    '--modules shell.zsh -y' \
    '--modules shell.zsh --unknown' \
    '--modules' \
    '--platform debian --yes'; do
    home=$(new_home "usage-${checks}")
    # Intentional word splitting supplies static invalid argument fixtures.
    # shellcheck disable=SC2086
    run_apply "$home" "$zsh_targets" $arguments
    check_equal "usage rejection status: ${arguments}" "$STATUS" 2
    check_zero_mutation "usage rejection does not mutate: ${arguments}"
done

home=$(new_home plan-rejects-yes)
OUTPUT=$(HOME="$home" "${PROJECT_ROOT}/bin/dotfiles" plan --modules shell.zsh --platform debian --yes 2>&1)
STATUS=$?
check_equal 'plan rejects apply-only --yes' "$STATUS" 2

home=$(new_home noninteractive)
plan=$(expected_step debian create prompt.starship home/dot_config/starship.toml .config/starship.toml)
run_apply "$home" "$starship_targets" --modules prompt.starship --platform debian
check_equal 'non-interactive apply without --yes status' "$STATUS" 2
check_contains 'non-interactive apply prints complete plan' "$plan"
check_contains 'non-interactive apply prints software disclosure' 'Software installation: none'
check_contains 'non-interactive apply is actionable' 'non-interactive apply requires --yes'
check_zero_mutation 'non-interactive apply without --yes does not mutate'
check_private_output 'non-interactive apply output is private'

home=$(new_home unsafe-selected-target)
ln -s /dev/null "$home/.zshrc"
run_apply "$home" "$zsh_targets" --modules shell.zsh --platform debian --yes
check_equal 'unsafe selected target apply status' "$STATUS" 3
check_zero_mutation 'unsafe selected target fails before mutation'

for answer in Yes ' yes' 'yes ' no '' EOF; do
    answer_name=${answer:-empty}
    home=$(new_home "cancel-${checks}")
    run_apply_tty "$answer" "$home" "$starship_targets" --modules prompt.starship --platform macos
    check_equal "interactive ${answer_name} cancellation status" "$STATUS" 0
    check_contains "interactive ${answer_name} prints cancellation" 'Cancelled. No changes were applied.'
    check_zero_mutation "interactive ${answer_name} cancellation does not mutate"
    check_private_output "interactive ${answer_name} cancellation output is private"
done

home=$(new_home interactive-yes)
plan=$(expected_step debian create shell.zsh home/dot_zshrc.tmpl .zshrc)
expected=$(printf '%s\n\nSoftware installation: none\n\nApply this configuration? Type yes to continue:\nApply complete: 1 completed, 0 failed, 0 unattempted' "$plan")
run_apply_tty yes "$home" "$zsh_targets" --modules shell.zsh --platform debian
check_equal 'interactive exact yes status' "$STATUS" 0
check_equal 'interactive exact yes output' "$OUTPUT" "$expected"
check_equal 'interactive exact yes invokes one apply' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
check_private_output 'interactive exact yes output is private'

for platform in macos debian; do
    home=$(new_home "${platform}-starship")
    printf 'unselected Zsh sentinel\n' > "$home/.zshrc"
    desired=$(render_desired "${platform}-starship" "$home" "" prompt.starship "" "$platform")
    expected_home="${TEST_ROOT}/homes/${platform}-starship-expected"
    cp -R "$home" "$expected_home"
    copy_target "$desired" "$expected_home" .config/starship.toml
    run_apply "$home" "$starship_targets" --modules prompt.starship --platform "$platform" --yes
    check_equal "${platform} Starship apply status" "$STATUS" 0
    check_contains "${platform} Starship apply success" 'Apply complete: 1 completed, 0 failed, 0 unattempted'
    check_equal "${platform} Starship invokes one target" "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
    check_equal "${platform} Starship leaves .zshrc untouched" "$(<"$home/.zshrc")" 'unselected Zsh sentinel'
    if cmp -s "$desired/.config/starship.toml" "$home/.config/starship.toml"; then pass "${platform} Starship bytes match fresh render"; else fail "${platform} Starship bytes match fresh render"; fi
    check_equal "${platform} Starship changes only its target and required parents" \
        "$(home_snapshot "$home")" "$(home_snapshot "$expected_home")"

    OUTPUT=$(HOME="$home" "${PROJECT_ROOT}/bin/dotfiles" plan --modules prompt.starship --platform "$platform" 2>&1)
    STATUS=$?
    check_equal "${platform} successful apply makes plan converged" "$OUTPUT" 'No changes.'
    before=$(line_count "$APPLY_INVOCATION_LOG")
    run_apply "$home" "$starship_targets" --modules prompt.starship --platform "$platform" --yes
    check_equal "${platform} second apply status" "$STATUS" 0
    check_equal "${platform} second apply exact no-change" "$OUTPUT" 'No changes.'
    check_equal "${platform} second apply invokes no apply" "$INVOCATIONS_AFTER" "$before"
    run_apply "$home" "$starship_targets" --modules prompt.starship --platform "$platform"
    check_equal "${platform} no-change apply without --yes status" "$STATUS" 0
    check_equal "${platform} no-change apply without --yes output" "$OUTPUT" 'No changes.'
    check_equal "${platform} no-change apply without --yes does not invoke apply" "$INVOCATIONS_AFTER" "$before"
done

home=$(new_home add-selection)
run_apply "$home" "$(printf '%s\n' '.config/starship.toml' '.zshrc')" --modules shell.zsh --add prompt.starship --platform debian --yes
check_equal '--add apply status' "$STATUS" 0
check_contains '--add applies shared resolver selection' 'Apply complete: 2 completed, 0 failed, 0 unattempted'

reset_artifact
home=$(new_home autosuggestions)
run_apply "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform macos --yes
check_equal 'autosuggestions apply status' "$STATUS" 0
check_contains 'autosuggestions applies dependency targets' 'Apply complete: 2 completed, 0 failed, 0 unattempted'
check_equal 'autosuggestions invokes two targets' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 2
recent=$(tail -n 2 "$APPLY_INVOCATION_LOG")
check_equal 'autosuggestions target order' "$recent" "$(printf 'apply\t.config/zsh/autosuggestions.zsh\napply\t.zshrc')"

for platform in macos debian; do
    reset_artifact
    home=$(new_home "${platform}-profile")
    desired=$(render_desired "${platform}-profile" "$home" shell.minimal "" "" "$platform")
    expected_home="${TEST_ROOT}/homes/${platform}-profile-expected"
    cp -R "$home" "$expected_home"
    copy_target "$desired" "$expected_home" .config/starship.toml
    copy_target "$desired" "$expected_home" .config/zsh/autosuggestions.zsh
    copy_target "$desired" "$expected_home" .zshrc
    run_apply "$home" "$profile_targets" --profile shell.minimal --platform "$platform" --yes
    check_equal "${platform} profile apply status" "$STATUS" 0
    check_contains "${platform} profile success count" 'Apply complete: 3 completed, 0 failed, 0 unattempted'
    check_equal "${platform} profile invokes three targets" "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 3
    check_equal "${platform} profile target order" "$(tail -n 3 "$APPLY_INVOCATION_LOG")" "$(printf 'apply\t.config/starship.toml\napply\t.config/zsh/autosuggestions.zsh\napply\t.zshrc')"
    check_equal "${platform} profile changes only planned targets and required parents" \
        "$(home_snapshot "$home")" "$(home_snapshot "$expected_home")"
done

reset_artifact
home=$(new_home mixed)
desired=$(render_desired mixed "$home" shell.minimal "" "" debian)
copy_target "$desired" "$home" .config/zsh/autosuggestions.zsh
printf 'outdated Zsh\n' > "$home/.zshrc"
run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
check_equal 'mixed apply status' "$STATUS" 0
check_contains 'mixed applies only two changed targets' 'Apply complete: 2 completed, 0 failed, 0 unattempted'
check_equal 'mixed invokes only changed targets' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 2
check_equal 'mixed changed target order' "$(tail -n 2 "$APPLY_INVOCATION_LOG")" "$(printf 'apply\t.config/starship.toml\napply\t.zshrc')"

reset_artifact
home=$(new_home narrower)
run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
optional_before=$(cksum "$home/.config/starship.toml" "$home/.config/zsh/autosuggestions.zsh")
run_apply "$home" "$zsh_targets" --modules shell.zsh --platform debian --yes
check_equal 'narrower Zsh apply status' "$STATUS" 0
check_contains 'narrower Zsh applies one target' 'Apply complete: 1 completed, 0 failed, 0 unattempted'
check_equal 'narrower Zsh invokes only .zshrc' "$(tail -n 1 "$APPLY_INVOCATION_LOG")" $'apply\t.zshrc'
check_equal 'narrower Zsh preserves omitted files' "$(cksum "$home/.config/starship.toml" "$home/.config/zsh/autosuggestions.zsh")" "$optional_before"
check_not_contains 'narrower Zsh output omits Starship target' 'chezmoi:target:.config/starship.toml'
check_not_contains 'narrower Zsh output omits autosuggestions target' 'chezmoi:target:.config/zsh/autosuggestions.zsh'

home=$(new_home state-drift)
export DOTFILES_PTY_CONFIRM_HOOK=$CONFIRM_HOOK
export DOTFILES_CONFIRM_HOOK_MODE=write-target
export DOTFILES_CONFIRM_HOOK_TARGET="$home/.config/starship.toml"
run_apply_tty yes "$home" "$starship_targets" --modules prompt.starship --platform debian
check_equal 'confirmation-time destination drift status' "$STATUS" 3
check_contains 'confirmation-time destination drift is actionable' 'configuration changed or became unsafe after confirmation'
check_equal 'confirmation-time destination drift invokes no apply' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
check_private_output 'confirmation-time destination drift output is private'

home=$(new_home update-state-drift)
mkdir -p "$home/.config"
printf 'first outdated state\n' > "$home/.config/starship.toml"
export DOTFILES_CONFIRM_HOOK_TARGET="$home/.config/starship.toml"
run_apply_tty yes "$home" "$starship_targets" --modules prompt.starship --platform debian
check_equal 'confirmation-time update-to-different-update drift status' "$STATUS" 3
check_contains 'confirmation-time update-to-different-update drift is actionable' \
    'configuration changed or became unsafe after confirmation'
check_equal 'confirmation-time update-to-different-update drift invokes no apply' \
    "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
check_equal 'confirmation-time update-to-different-update preserves the newer bytes' \
    "$(<"$home/.config/starship.toml")" 'changed while confirmation was pending'

home=$(new_home prerequisite-drift)
export DOTFILES_CONFIRM_HOOK_MODE=remove-prerequisite
export DOTFILES_CONFIRM_HOOK_TARGET="$PROBE_BIN/starship"
run_apply_tty yes "$home" "$starship_targets" --modules prompt.starship --platform macos
check_equal 'confirmation-time prerequisite drift status' "$STATUS" 5
check_equal 'confirmation-time prerequisite drift invokes no apply' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
chmod +x "$PROBE_BIN/starship"

reset_artifact
home=$(new_home artifact-drift)
export DOTFILES_CONFIRM_HOOK_MODE=break-artifact
export DOTFILES_CONFIRM_HOOK_TARGET="$ARTIFACT_LINK"
run_apply_tty yes "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform debian
check_equal 'confirmation-time artifact drift status' "$STATUS" 5
check_equal 'confirmation-time artifact drift invokes no apply' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
export DOTFILES_PTY_CONFIRM_HOOK=
export DOTFILES_CONFIRM_HOOK_MODE=
export DOTFILES_CONFIRM_HOOK_TARGET=

reset_artifact
: > "$PLAN_INVOCATION_LOG"
export DOTFILES_PLAN_PROBE_AFTER_STATUS_MODE=retarget-artifact
export DOTFILES_PLAN_PROBE_AFTER_STATUS_AT=2
export DOTFILES_RETARGET_LINK=$ARTIFACT_LINK
export DOTFILES_RETARGET_TARGET=$ARTIFACT_ALTERNATE
home=$(new_home immediate-artifact-drift)
run_apply "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform macos --yes
check_equal 'immediate artifact drift status' "$STATUS" 6
check_contains 'immediate artifact drift reports partial failure' 'Apply failed: 1 completed, 1 failed, 0 unattempted'
check_contains 'immediate artifact drift reports completed target' 'completed: shell.zsh.autosuggestions chezmoi:target:.config/zsh/autosuggestions.zsh'
check_contains 'immediate artifact drift reports failed Zsh target' 'failed: shell.zsh chezmoi:target:.zshrc'
check_equal 'immediate artifact drift stops before Zsh apply' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
export DOTFILES_PLAN_PROBE_AFTER_STATUS_MODE=
export DOTFILES_RETARGET_LINK=
export DOTFILES_RETARGET_TARGET=

for failed_target in .config/starship.toml .config/zsh/autosuggestions.zsh .zshrc; do
    reset_artifact
    home=$(new_home "failure-${checks}")
    export DOTFILES_APPLY_PROBE_MODE=fail-target
    export DOTFILES_APPLY_PROBE_TARGET=$failed_target
    run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
    case "$failed_target" in
        .config/starship.toml) completed=0; unattempted=2; invoked=1; failed_module=prompt.starship ;;
        .config/zsh/autosuggestions.zsh) completed=1; unattempted=1; invoked=2; failed_module=shell.zsh.autosuggestions ;;
        .zshrc) completed=2; unattempted=0; invoked=3; failed_module=shell.zsh ;;
    esac
    check_equal "failure at ${failed_target} status" "$STATUS" 6
    check_contains "failure at ${failed_target} counts" "Apply failed: ${completed} completed, 1 failed, ${unattempted} unattempted"
    check_equal "failure at ${failed_target} stops later invocation" "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" "$invoked"
    check_contains "failure at ${failed_target} names failed owner" "failed: ${failed_module} chezmoi:target:${failed_target}"
done
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=

home=$(new_home wrong-bytes)
export DOTFILES_APPLY_PROBE_MODE=wrong-bytes
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
run_apply "$home" "$starship_targets" --modules prompt.starship --platform macos --yes
check_equal 'success with wrong bytes status' "$STATUS" 6
check_contains 'success with wrong bytes is failed, not completed' 'Apply failed: 0 completed, 1 failed, 0 unattempted'
export DOTFILES_APPLY_PROBE_MODE=delegate

for verification_mode in disappear replace-symlink; do
    home=$(new_home "verification-${verification_mode}")
    export DOTFILES_APPLY_PROBE_MODE=$verification_mode
    export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
    run_apply "$home" "$starship_targets" --modules prompt.starship --platform debian --yes
    check_equal "post-target ${verification_mode} status" "$STATUS" 6
    check_contains "post-target ${verification_mode} is failed" 'Apply failed: 0 completed, 1 failed, 0 unattempted'
done
export DOTFILES_APPLY_PROBE_MODE=delegate

reset_artifact
home=$(new_home symlink-swap)
export DOTFILES_APPLY_PROBE_MODE=swap-next-symlink
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
export DOTFILES_APPLY_PROBE_NEXT_TARGET=.config/zsh/autosuggestions.zsh
run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
check_equal 'symlink swap before next target status' "$STATUS" 6
check_contains 'symlink swap reports exact partial state' 'Apply failed: 1 completed, 1 failed, 1 unattempted'
check_equal 'symlink swap stops before affected invocation' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=
export DOTFILES_APPLY_PROBE_NEXT_TARGET=

reset_artifact
home=$(new_home between-target-edit)
mkdir -p "$home/.config/zsh"
printf 'first outdated state\n' > "$home/.config/zsh/autosuggestions.zsh"
export DOTFILES_APPLY_PROBE_MODE=edit-next-target
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
export DOTFILES_APPLY_PROBE_NEXT_TARGET=.config/zsh/autosuggestions.zsh
run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
check_equal 'between-target byte edit status' "$STATUS" 6
check_contains 'between-target byte edit reports exact partial state' \
    'Apply failed: 1 completed, 1 failed, 1 unattempted'
check_equal 'between-target byte edit stops before affected invocation' \
    "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
check_equal 'between-target byte edit preserves the newer bytes' \
    "$(<"$home/.config/zsh/autosuggestions.zsh")" 'changed between target invocations'
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=
export DOTFILES_APPLY_PROBE_NEXT_TARGET=

reset_artifact
home=$(new_home directory-swap)
export DOTFILES_APPLY_PROBE_MODE=swap-next-directory
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
export DOTFILES_APPLY_PROBE_NEXT_TARGET=.config/zsh/autosuggestions.zsh
run_apply "$home" "$profile_targets" --profile shell.minimal --platform macos --yes
check_equal 'directory swap before next target status' "$STATUS" 6
check_contains 'directory swap reports exact partial state' 'Apply failed: 1 completed, 1 failed, 1 unattempted'
check_equal 'directory swap stops before affected invocation' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=
export DOTFILES_APPLY_PROBE_NEXT_TARGET=

home=$(new_home signal-before-confirmation)
export DOTFILES_PTY_CONFIRM_HOOK=$CONFIRM_HOOK
export DOTFILES_CONFIRM_HOOK_MODE=term
run_apply_tty yes "$home" "$starship_targets" --modules prompt.starship --platform macos
check_equal 'signal before confirmation status' "$STATUS" 143
check_zero_mutation 'signal before confirmation does not mutate'
export DOTFILES_PTY_CONFIRM_HOOK=
export DOTFILES_CONFIRM_HOOK_MODE=

for signal_target in .config/starship.toml .config/zsh/autosuggestions.zsh; do
    reset_artifact
    home=$(new_home "signal-${checks}")
    export DOTFILES_APPLY_PROBE_MODE=term-target
    export DOTFILES_APPLY_PROBE_TARGET=$signal_target
    run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
    case "$signal_target" in
        .config/starship.toml) signal_completed=0; signal_unattempted=2 ;;
        *) signal_completed=1; signal_unattempted=1 ;;
    esac
    check_equal "signal during ${signal_target} status" "$STATUS" 143
    check_contains "signal during ${signal_target} partial report" "Apply failed: ${signal_completed} completed, 1 failed, ${signal_unattempted} unattempted"
done
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=

home=$(new_home inspect-private)
export DOTFILES_PTY_CONFIRM_HOOK=$CONFIRM_HOOK
export DOTFILES_CONFIRM_HOOK_MODE=inspect-private
run_apply_tty no "$home" "$starship_targets" --modules prompt.starship --platform debian
if [ -s "$CONFIRM_PRIVATE_MODE_LOG" ] && ! grep -Ev '^(directory 700|file 600)$' "$CONFIRM_PRIVATE_MODE_LOG" | grep -q .; then
    pass 'displayed apply authority uses only mode 700 directories and mode 600 files'
else
    STATUS=1; OUTPUT='unexpected displayed authority mode'; fail 'displayed apply authority uses only mode 700 directories and mode 600 files'
fi
export DOTFILES_PTY_CONFIRM_HOOK=
export DOTFILES_CONFIRM_HOOK_MODE=

if [ -f "$APPLY_PRIVATE_MODE_LOG" ] && ! grep -Ev '^600 700 700 700 600 600 600 600 700$' "$APPLY_PRIVATE_MODE_LOG" | grep -q .; then
    pass 'apply context, cache, records, and captures use restrictive modes'
else
    STATUS=1; OUTPUT='unexpected apply private mode'; fail 'apply context, cache, records, and captures use restrictive modes'
fi

cleanup_ok=1
cleanup_remaining=
for path_log in "$PRIVATE_PATH_LOG" "$APPLY_PRIVATE_PATH_LOG" "$CONTEXT_PATH_LOG"; do
    [ -f "$path_log" ] || continue
    while IFS= read -r private_path; do
        [ -n "$private_path" ] || continue
        if [ -e "$private_path" ]; then
            cleanup_ok=0
            cleanup_remaining="${cleanup_remaining}${cleanup_remaining:+ }${private_path}"
        fi
    done < "$path_log"
done
if find "$TMPDIR" -maxdepth 1 -type d \( -name 'dotfiles-apply.*' -o -name 'dotfiles-plan.*' -o -name 'dotfiles-render.*' \) -print -quit | grep -q .; then
    cleanup_ok=0
    cleanup_remaining="${cleanup_remaining}${cleanup_remaining:+ }$(find "$TMPDIR" -maxdepth 1 -type d \( -name 'dotfiles-apply.*' -o -name 'dotfiles-plan.*' -o -name 'dotfiles-render.*' \) -print)"
fi
if [ "$cleanup_ok" -eq 1 ]; then pass 'all apply, plan, render, cache, state, and capture paths are removed'; else STATUS=1; OUTPUT="private paths remain: ${cleanup_remaining}"; fail 'all apply, plan, render, cache, state, and capture paths are removed'; fi

if [ ! -e "$PROBE_LOG" ]; then
    pass 'apply invokes no provider, prerequisite, artifact, pager, editor, external diff, secret, network, or privilege helper'
else
    STATUS=97
    OUTPUT=$(<"$PROBE_LOG")
    fail 'apply invokes no provider, prerequisite, artifact, pager, editor, external diff, secret, network, or privilege helper'
fi

if [ "$failures" -ne 0 ]; then
    printf '%s of %s apply checks failed\n' "$failures" "$checks" >&2
    exit 1
fi

printf '%s apply checks passed\n' "$checks"
