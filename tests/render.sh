#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
TEST_PARENT=${TMPDIR:-/tmp}
TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-render-tests.XXXXXX")

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
PROBE_BIN="${TEST_ROOT}/probe-bin"
PROBE_LOG="${TEST_ROOT}/probe.log"
CONTEXT_PATH_LOG="${TEST_ROOT}/context-paths.log"
CONTEXT_MODE_LOG="${TEST_ROOT}/context-modes.log"
CONTEXT_SUMMARY_LOG="${TEST_ROOT}/context-summary.log"
TEST_HOME="${TEST_ROOT}/private-user-home"
ARTIFACT_ROOT="${TEST_ROOT}/share-root"
ARTIFACT_DIRECTORY="${ARTIFACT_ROOT}/zsh-autosuggestions"
ARTIFACT_LINK="${ARTIFACT_DIRECTORY}/zsh-autosuggestions.zsh"
ARTIFACT_TARGET="${ARTIFACT_DIRECTORY}/canonical-plugin.zsh"

mkdir -p "$PROBE_BIN" "$TEST_HOME/.config/chezmoi" "${TEST_ROOT}/tmp"
printf '%s\n' \
    '[data.dotfiles]' \
    'schema = 999' \
    'private_machine_value = "must-not-be-read"' > "$TEST_HOME/.config/chezmoi/chezmoi.toml"
for probe in brew mise apt apt-get dnf yum pacman apk installer zsh starship; do
    printf '%s\n' \
        '#!/bin/sh' \
        'printf "%s\n" "$0 $*" >> "$DOTFILES_PROBE_LOG"' \
        'exit 97' > "${PROBE_BIN}/${probe}"
    chmod +x "${PROBE_BIN}/${probe}"
done

export DOTFILES_REAL_CHEZMOI="$REAL_CHEZMOI"
export DOTFILES_RENDER_CHEZMOI_BIN="$RENDER_PROBE"
export DOTFILES_CONTEXT_PATH_LOG="$CONTEXT_PATH_LOG"
export DOTFILES_CONTEXT_MODE_LOG="$CONTEXT_MODE_LOG"
export DOTFILES_CONTEXT_SUMMARY_LOG="$CONTEXT_SUMMARY_LOG"
export DOTFILES_ALLOWED_TEST_ROOT="$TEST_ROOT"
export DOTFILES_PROBE_LOG="$PROBE_LOG"
export DOTFILES_CHEZMOI_PROBE_MODE=delegate
export DOTFILES_RETARGET_LINK=
export DOTFILES_SHARE_ROOTS="$ARTIFACT_ROOT"
export HOME="$TEST_HOME"
export PATH="${PROBE_BIN}:/usr/bin:/bin"
export TMPDIR="${TEST_ROOT}/tmp"

SOURCE_DIR=$PROJECT_ROOT
CHEZMOI_BIN=$REAL_CHEZMOI

failures=0
checks=0
OUTPUT=
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

check_equal() {
    local_name=$1
    local_actual=$2
    local_expected=$3
    if [ "$local_actual" = "$local_expected" ]; then
        pass "$local_name"
    else
        STATUS=1
        OUTPUT="expected ${local_expected}; got ${local_actual}"
        fail "$local_name"
    fi
}

check_true() {
    local_name=$1
    shift
    if "$@"; then
        pass "$local_name"
    else
        STATUS=$?
        OUTPUT="condition failed: $*"
        fail "$local_name"
    fi
}

check_file_contains() {
    local_name=$1
    local_file=$2
    local_text=$3
    if [ -f "$local_file" ] && grep -F "$local_text" "$local_file" >/dev/null 2>&1; then
        pass "$local_name"
    else
        STATUS=1
        OUTPUT="missing expected text: ${local_text}"
        fail "$local_name"
    fi
}

check_file_not_contains() {
    local_name=$1
    local_file=$2
    local_text=$3
    if [ -f "$local_file" ] && ! grep -F "$local_text" "$local_file" >/dev/null 2>&1; then
        pass "$local_name"
    else
        STATUS=1
        OUTPUT="unexpected text: ${local_text}"
        fail "$local_name"
    fi
}

check_file_count() {
    local_name=$1
    local_file=$2
    local_text=$3
    local_expected=$4
    local local_actual
    local_actual=$(grep -F -c "$local_text" "$local_file" 2>/dev/null || true)
    check_equal "$local_name" "$local_actual" "$local_expected"
}

run_render() {
    local_output=$1
    local_profile=$2
    local_modules=$3
    local_additional=$4
    local_platform=$5
    OUTPUT=$(dotfiles_render_selection "$local_output" "$local_profile" "$local_modules" "$local_additional" "$local_platform" 2>&1)
    STATUS=$?
}

expect_render_status() {
    local_name=$1
    local_expected=$2
    shift 2
    run_render "$@"
    if [ "$STATUS" -eq "$local_expected" ]; then
        pass "$local_name"
    else
        fail "$local_name"
    fi
}

rendered_files() {
    (CDPATH= cd -- "$1" && find . -type f -print | LC_ALL=C sort)
}

reset_artifact() {
    rm -rf -- "$ARTIFACT_DIRECTORY"
    mkdir -p "$ARTIFACT_DIRECTORY"
    printf '%s\n' \
        '#!/bin/sh' \
        'printf "artifact invoked\n" >> "$DOTFILES_PROBE_LOG"' \
        'exit 97' > "$ARTIFACT_TARGET"
    chmod +x "$ARTIFACT_TARGET"
    ln -s "$(basename -- "$ARTIFACT_TARGET")" "$ARTIFACT_LINK"
}

set_artifact_state() {
    local_state=$1
    rm -rf -- "$ARTIFACT_DIRECTORY"
    mkdir -p "$ARTIFACT_DIRECTORY"
    case "$local_state" in
        broken) ln -s missing "$ARTIFACT_LINK" ;;
        loop) ln -s "$(basename -- "$ARTIFACT_LINK")" "$ARTIFACT_LINK" ;;
        escape) ln -s /dev/null "$ARTIFACT_LINK" ;;
        directory) mkdir "$ARTIFACT_LINK" ;;
        fifo) mkfifo "$ARTIFACT_LINK" ;;
        control)
            local_control_target="${ARTIFACT_DIRECTORY}/canonical"$'\t'"plugin.zsh"
            printf 'metadata only\n' > "$local_control_target"
            ln -s "$(basename -- "$local_control_target")" "$ARTIFACT_LINK"
            ;;
        *) return 1 ;;
    esac
}

home_snapshot() {
    (
        CDPATH= cd -- "$HOME" || exit 1
        find . -print | LC_ALL=C sort
        find . -type f -exec cksum {} \; | LC_ALL=C sort
    )
}

reset_artifact
HOME_SNAPSHOT_BEFORE=$(home_snapshot)
expected_zsh='./.zshrc'
expected_starship='./.config/starship.toml'
expected_zsh_starship=$(printf '%s\n' './.config/starship.toml' './.zshrc')
expected_autosuggestions=$(printf '%s\n' './.config/zsh/autosuggestions.zsh' './.zshrc')
expected_profile=$(printf '%s\n' './.config/starship.toml' './.config/zsh/autosuggestions.zsh' './.zshrc')
canonical_artifact=$(realpath "$ARTIFACT_LINK")

for platform in macos debian; do
    output="${TEST_ROOT}/matrix-${platform}-zsh"
    mkdir "$output"
    expect_render_status "${platform} Zsh-only render succeeds" 0 "$output" "" shell.zsh "" "$platform"
    check_equal "${platform} Zsh-only target set" "$(rendered_files "$output")" "$expected_zsh"
    check_file_not_contains "${platform} Zsh-only omits autosuggestions" "$output/.zshrc" autosuggestions
    check_file_not_contains "${platform} Zsh-only omits Starship" "$output/.zshrc" 'starship init zsh'

    output="${TEST_ROOT}/matrix-${platform}-starship"
    mkdir "$output"
    expect_render_status "${platform} Starship-only render succeeds" 0 "$output" "" prompt.starship "" "$platform"
    check_equal "${platform} Starship-only target set" "$(rendered_files "$output")" "$expected_starship"
    check_true "${platform} Starship-only does not render .zshrc" test ! -e "$output/.zshrc"

    output="${TEST_ROOT}/matrix-${platform}-zsh-starship"
    mkdir "$output"
    expect_render_status "${platform} Zsh plus Starship render succeeds" 0 "$output" "" shell.zsh,prompt.starship "" "$platform"
    check_equal "${platform} Zsh plus Starship target set" "$(rendered_files "$output")" "$expected_zsh_starship"
    check_file_count "${platform} Zsh plus Starship activates once" "$output/.zshrc" 'starship init zsh' 1
    check_file_not_contains "${platform} Zsh plus Starship omits autosuggestions" "$output/.zshrc" autosuggestions

    output="${TEST_ROOT}/matrix-${platform}-autosuggestions"
    mkdir "$output"
    expect_render_status "${platform} autosuggestions render succeeds" 0 "$output" "" shell.zsh.autosuggestions "" "$platform"
    check_equal "${platform} autosuggestions target set" "$(rendered_files "$output")" "$expected_autosuggestions"
    check_file_count "${platform} autosuggestions config is referenced once" "$output/.zshrc" 'source -- "$HOME/.config/zsh/autosuggestions.zsh"' 1
    check_file_count "${platform} canonical artifact is sourced once" "$output/.zshrc" "source -- '${canonical_artifact}'" 1
    check_file_not_contains "${platform} autosuggestions omits Starship" "$output/.zshrc" 'starship init zsh'

    output="${TEST_ROOT}/matrix-${platform}-profile"
    mkdir "$output"
    expect_render_status "${platform} profile render succeeds" 0 "$output" shell.minimal "" "" "$platform"
    check_equal "${platform} profile target set" "$(rendered_files "$output")" "$expected_profile"
    check_file_count "${platform} profile activates Starship once" "$output/.zshrc" 'starship init zsh' 1
    check_file_count "${platform} profile sources artifact once" "$output/.zshrc" "source -- '${canonical_artifact}'" 1

    config_line=$(grep -nF 'source -- "$HOME/.config/zsh/autosuggestions.zsh"' "$output/.zshrc" | cut -d: -f1)
    artifact_line=$(grep -nF "source -- '${canonical_artifact}'" "$output/.zshrc" | cut -d: -f1)
    starship_line=$(grep -nF 'starship init zsh' "$output/.zshrc" | cut -d: -f1)
    if [ "$config_line" -lt "$artifact_line" ] && [ "$artifact_line" -lt "$starship_line" ]; then
        pass "${platform} profile activation order is deterministic"
    else
        STATUS=1
        OUTPUT="activation lines: ${config_line},${artifact_line},${starship_line}"
        fail "${platform} profile activation order is deterministic"
    fi

    output="${TEST_ROOT}/matrix-${platform}-add"
    mkdir "$output"
    expect_render_status "${platform} add feeds shared render resolution" 0 "$output" "" shell.zsh prompt.starship "$platform"
    check_equal "${platform} add target set" "$(rendered_files "$output")" "$expected_zsh_starship"
done

repeat_one="${TEST_ROOT}/repeat-one"
repeat_two="${TEST_ROOT}/repeat-two"
mkdir "$repeat_one" "$repeat_two"
expect_render_status "first deterministic render succeeds" 0 "$repeat_one" shell.minimal "" "" debian
expect_render_status "second deterministic render succeeds" 0 "$repeat_two" "" shell.zsh.autosuggestions,prompt.starship "" debian
check_true "profile and direct render outputs are byte-identical" diff -r "$repeat_one" "$repeat_two"
check_true "Starship plain source remains byte-stable" cmp "${PROJECT_ROOT}/home/dot_config/starship.toml" "$repeat_one/.config/starship.toml"
check_true "autosuggestions plain source remains byte-stable" cmp "${PROJECT_ROOT}/home/dot_config/zsh/autosuggestions.zsh" "$repeat_one/.config/zsh/autosuggestions.zsh"

stale_output="${TEST_ROOT}/stale-output"
mkdir "$stale_output"
expect_render_status "broad stale-state fixture render succeeds" 0 "$stale_output" shell.minimal "" "" macos
expect_render_status "narrow stale-state fixture render succeeds" 0 "$stale_output" "" shell.zsh "" macos
check_equal "narrow render leaves old optional files without cleanup" "$(rendered_files "$stale_output")" "$expected_profile"
check_file_not_contains "narrow render removes autosuggestions activation" "$stale_output/.zshrc" autosuggestions
check_file_not_contains "narrow render removes Starship activation" "$stale_output/.zshrc" 'starship init zsh'

starship_existing="${TEST_ROOT}/starship-existing"
mkdir -p "$starship_existing"
printf 'unmanaged sentinel\n' > "$starship_existing/.zshrc"
expect_render_status "Starship render with existing .zshrc succeeds" 0 "$starship_existing" "" prompt.starship "" debian
check_equal "Starship render leaves existing .zshrc byte-stable" "$(sed -n '1p' "$starship_existing/.zshrc")" 'unmanaged sentinel'

copy_failure_output="${TEST_ROOT}/copy-failure-output"
copy_count_file="${TEST_ROOT}/copy-count"
mkdir "$copy_failure_output"
printf '%s\n' \
    '#!/bin/sh' \
    'count=0' \
    '[ ! -f "$DOTFILES_COPY_COUNT_FILE" ] || IFS= read -r count < "$DOTFILES_COPY_COUNT_FILE"' \
    'count=$((count + 1))' \
    'printf "%s\n" "$count" > "$DOTFILES_COPY_COUNT_FILE"' \
    '[ "$count" -ne "$DOTFILES_COPY_FAIL_AT" ] || exit 98' \
    'exec /bin/cp "$@"' > "${PROBE_BIN}/cp"
chmod +x "${PROBE_BIN}/cp"
export DOTFILES_COPY_COUNT_FILE=$copy_count_file
export DOTFILES_COPY_FAIL_AT=3
expect_render_status "late selected-target copy failure is reported" 4 "$copy_failure_output" shell.minimal "" "" debian
check_equal "late selected-target copy failure publishes no target" "$(rendered_files "$copy_failure_output")" ""
rm -f -- "${PROBE_BIN}/cp"
unset DOTFILES_COPY_COUNT_FILE DOTFILES_COPY_FAIL_AT

publish_failure_output="${TEST_ROOT}/publish-failure-output"
publish_count_file="${TEST_ROOT}/publish-count"
mkdir -p "$publish_failure_output/.config/zsh"
printf 'old starship\n' > "$publish_failure_output/.config/starship.toml"
printf 'old autosuggestions\n' > "$publish_failure_output/.config/zsh/autosuggestions.zsh"
printf 'old zsh\n' > "$publish_failure_output/.zshrc"
publish_snapshot_before=$(find "$publish_failure_output" -type f -exec cksum {} \; | LC_ALL=C sort)
printf '%s\n' \
    '#!/bin/sh' \
    'count=0' \
    '[ ! -f "$DOTFILES_PUBLISH_COUNT_FILE" ] || IFS= read -r count < "$DOTFILES_PUBLISH_COUNT_FILE"' \
    'count=$((count + 1))' \
    'printf "%s\n" "$count" > "$DOTFILES_PUBLISH_COUNT_FILE"' \
    '[ "$count" -ne "$DOTFILES_PUBLISH_FAIL_AT" ] || exit 98' \
    'exec /bin/mv "$@"' > "${PROBE_BIN}/mv"
chmod +x "${PROBE_BIN}/mv"
export DOTFILES_PUBLISH_COUNT_FILE=$publish_count_file
export DOTFILES_PUBLISH_FAIL_AT=3
expect_render_status "late selected-target publication failure is reported" 4 "$publish_failure_output" shell.minimal "" "" macos
rm -f -- "${PROBE_BIN}/mv"
unset DOTFILES_PUBLISH_COUNT_FILE DOTFILES_PUBLISH_FAIL_AT
publish_snapshot_after=$(find "$publish_failure_output" -type f -exec cksum {} \; | LC_ALL=C sort)
check_equal "late publication failure restores every prior target" "$publish_snapshot_after" "$publish_snapshot_before"
check_equal "late publication failure leaves no temporary target" "$(find "$publish_failure_output" -type f -name '.dotfiles-render.*' -print)" ""

: > "$CONTEXT_SUMMARY_LOG"
context_output="${TEST_ROOT}/context-output"
mkdir "$context_output"
expect_render_status "context inspection render succeeds" 0 "$context_output" shell.minimal "" "" debian
check_file_not_contains "local chezmoi config cannot enter render context" "$CONTEXT_SUMMARY_LOG" private_machine_value
check_file_contains "context schema is fixed" "$CONTEXT_SUMMARY_LOG" 'schema = 1'
check_file_contains "context platform is fixed" "$CONTEXT_SUMMARY_LOG" 'platform = "debian"'
check_file_contains "context modules preserve resolver order" "$CONTEXT_SUMMARY_LOG" 'modules = ["shell.zsh", "shell.zsh.autosuggestions", "prompt.starship"]'
check_file_contains "context sources use normalized-target order" "$CONTEXT_SUMMARY_LOG" 'sources = ["home/dot_config/starship.toml", "home/dot_config/zsh/autosuggestions.zsh", "home/dot_zshrc.tmpl"]'
check_file_contains "context artifact is present but probe-redacted" "$CONTEXT_SUMMARY_LOG" 'autosuggestions_artifact = "<redacted>"'
check_file_not_contains "context inspection log contains no raw test root" "$CONTEXT_SUMMARY_LOG" "$TEST_ROOT"

quote_root="${TEST_ROOT}/quote';false;#"
quote_directory="${quote_root}/zsh-autosuggestions"
quote_link="${quote_directory}/zsh-autosuggestions.zsh"
quote_target="${quote_directory}/canonical'plugin.zsh"
mkdir -p "$quote_directory"
printf 'metadata only\n' > "$quote_target"
ln -s "$(basename -- "$quote_target")" "$quote_link"
saved_roots=$DOTFILES_SHARE_ROOTS
export DOTFILES_SHARE_ROOTS=$quote_root
quote_output="${TEST_ROOT}/quote-output"
mkdir "$quote_output"
expect_render_status "single-quote artifact render succeeds" 0 "$quote_output" "" shell.zsh.autosuggestions "" macos
quote_canonical=$(realpath "$quote_link")
quote_remaining=$quote_canonical
quote_expected="'"
while case "$quote_remaining" in *"'"*) true ;; *) false ;; esac; do
    quote_prefix=${quote_remaining%%\'*}
    quote_remaining=${quote_remaining#*\'}
    quote_expected="${quote_expected}${quote_prefix}'\\''"
done
quote_expected="${quote_expected}${quote_remaining}'"
check_file_contains "single-quote artifact uses exact safe Zsh literal" "$quote_output/.zshrc" "source -- ${quote_expected}"
check_true "single-quote rendered Zsh remains syntactically valid" bash -n "$quote_output/.zshrc"
export DOTFILES_SHARE_ROOTS=$saved_roots

reset_artifact
canonical_artifact=$(realpath "$ARTIFACT_LINK")
export DOTFILES_CHEZMOI_PROBE_MODE=retarget
export DOTFILES_RETARGET_LINK=$ARTIFACT_LINK
retarget_output="${TEST_ROOT}/retarget-output"
mkdir "$retarget_output"
expect_render_status "symlink retarget after canonical resolution renders safely" 0 "$retarget_output" "" shell.zsh.autosuggestions "" debian
check_file_contains "retarget render keeps canonical contained candidate" "$retarget_output/.zshrc" "source -- '${canonical_artifact}'"
check_file_not_contains "retarget render never stores lexical artifact link" "$retarget_output/.zshrc" "$ARTIFACT_LINK"
check_file_not_contains "retarget render never follows escaped replacement" "$retarget_output/.zshrc" /dev/null
export DOTFILES_CHEZMOI_PROBE_MODE=delegate
export DOTFILES_RETARGET_LINK=

for state in broken loop escape directory fifo control; do
    set_artifact_state "$state"
    failure_output="${TEST_ROOT}/failure-${state}"
    mkdir "$failure_output"
    run_render "$failure_output" "" shell.zsh.autosuggestions "" debian
    if [ "$STATUS" -ne 0 ] && [ -z "$(rendered_files "$failure_output")" ]; then
        pass "${state} artifact fails before rendering"
    else
        fail "${state} artifact fails before rendering"
    fi
    case "$OUTPUT" in
        *"$TEST_ROOT"*|*"$(id -un)"*|*"$(hostname)"*) fail "${state} artifact failure is path-private" ;;
        *) pass "${state} artifact failure is path-private" ;;
    esac
done

reset_artifact
export DOTFILES_CHEZMOI_PROBE_MODE=fail
probe_failure_output="${TEST_ROOT}/probe-failure"
mkdir "$probe_failure_output"
expect_render_status "chezmoi failure remains read-only" 4 "$probe_failure_output" "" prompt.starship "" macos
check_equal "chezmoi failure commits no rendered target" "$(rendered_files "$probe_failure_output")" ""

export DOTFILES_CHEZMOI_PROBE_MODE=term
probe_term_output="${TEST_ROOT}/probe-term"
mkdir "$probe_term_output"
expect_render_status "handled interruption exits with signal status" 143 "$probe_term_output" "" prompt.starship "" debian
check_equal "handled interruption commits no rendered target" "$(rendered_files "$probe_term_output")" ""
export DOTFILES_CHEZMOI_PROBE_MODE=delegate

home_output="${HOME}/render-output"
mkdir "$home_output"
expect_render_status "renderer refuses a home-directory output" 3 "$home_output" "" shell.zsh "" macos
rmdir "$home_output"
expect_render_status "renderer rejects unknown module IDs through catalog" 3 "${TEST_ROOT}/context-output" "" shell.unknown "" debian

check_equal "fixture HOME remains byte-stable" "$(home_snapshot)" "$HOME_SNAPSHOT_BEFORE"
help_output=$("${PROJECT_ROOT}/bin/dotfiles" help)
case "$help_output" in
    *'dotfiles render'*) STATUS=1; OUTPUT="public help exposes an internal render command"; fail "public help has no render command" ;;
    *) pass "public help has no render command" ;;
esac

context_cleanup_ok=1
if [ -f "$CONTEXT_PATH_LOG" ]; then
    while IFS= read -r context_path; do
        [ -n "$context_path" ] || continue
        if [ -e "$context_path" ] || [ -d "$(dirname -- "$context_path")" ]; then
            context_cleanup_ok=0
        fi
    done < "$CONTEXT_PATH_LOG"
fi
if [ "$context_cleanup_ok" -eq 1 ]; then
    pass "every observed context and private directory is removed"
else
    STATUS=1
    OUTPUT="an observed render context remains"
    fail "every observed context and private directory is removed"
fi

if [ -f "$CONTEXT_MODE_LOG" ] && ! grep -Ev '^600 700$' "$CONTEXT_MODE_LOG" | grep -q .; then
    pass "every observed context and private directory has restrictive mode"
else
    STATUS=1
    OUTPUT="unexpected context or directory mode"
    fail "every observed context and private directory has restrictive mode"
fi

if [ ! -e "$PROBE_LOG" ]; then
    pass "rendering invokes no provider, prerequisite, or external artifact"
else
    STATUS=97
    OUTPUT="an external probe was invoked"
    fail "rendering invokes no provider, prerequisite, or external artifact"
fi

if [ "$failures" -ne 0 ]; then
    printf '%s of %s render checks failed\n' "$failures" "$checks" >&2
    exit 1
fi

printf '%s render checks passed\n' "$checks"
