#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
CLI="${PROJECT_ROOT}/bin/dotfiles"
FIXTURES="${PROJECT_ROOT}/tests/fixtures"
VALID="${FIXTURES}/valid"

failures=0
checks=0
OUTPUT=
STATUS=0

run_command() {
    OUTPUT=$("$@" 2>&1)
    STATUS=$?
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

expect_exact() {
    name=$1
    expected_status=$2
    expected_output=$3
    shift 3
    run_command "$@"
    if [ "$STATUS" -eq "$expected_status" ] && [ "$OUTPUT" = "$expected_output" ]; then
        pass "$name"
    else
        fail "$name"
    fi
}

expect_contains() {
    name=$1
    expected_status=$2
    expected_text=$3
    shift 3
    run_command "$@"
    case "$OUTPUT" in
        *"$expected_text"*)
            contains=1
            ;;
        *)
            contains=0
            ;;
    esac
    if [ "$STATUS" -eq "$expected_status" ] && [ "$contains" -eq 1 ]; then
        pass "$name"
    else
        fail "$name"
    fi
}

expect_not_contains() {
    name=$1
    unexpected_text=$2
    shift 2
    run_command "$@"
    case "$OUTPUT" in
        *"$unexpected_text"*)
            fail "$name"
            ;;
        *)
            if [ "$STATUS" -eq 0 ]; then
                pass "$name"
            else
                fail "$name"
            fi
            ;;
    esac
}

expected_profile=$(printf '%s\n' \
    shell.zsh \
    shell.zsh.autosuggestions \
    prompt.starship)

expected_with_terminal=$(printf '%s\n' \
    shell.zsh \
    shell.zsh.autosuggestions \
    prompt.starship \
    terminal.ghostty)

expect_exact "version is stable" 0 "dotfiles 0.1.0-dev" "$CLI" version
expect_contains "help is available" 0 "All commands in this release are read-only." "$CLI" help
expect_exact "empty production catalog validates" 0 "catalog valid: 0 modules, 0 profiles" "$CLI" catalog validate
expect_exact "fixture catalog validates" 0 "catalog valid: 5 modules, 1 profiles" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" catalog validate
expect_contains "module list filters for Debian" 0 "shell.zsh" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" module list --platform debian
expect_not_contains "Debian list excludes macOS terminal" "terminal.ghostty" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" module list --platform debian
expect_contains "module list all includes terminal" 0 "terminal.ghostty" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" module list --all
expect_contains "module show exposes dependency" 0 "depends: shell.zsh" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" module show shell.zsh.autosuggestions
expect_contains "profile list filters by platform" 0 "shell.minimal" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" profile list --platform debian
expect_contains "profile show exposes requested modules" 0 "modules: shell.zsh,shell.zsh.autosuggestions,prompt.starship" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" profile show shell.minimal
expect_exact "profile resolves deterministically" 0 "$expected_profile" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" resolve --profile shell.minimal --platform debian
expect_exact "custom composition resolves dependencies" 0 "$expected_profile" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" resolve --modules shell.zsh.autosuggestions,prompt.starship --platform debian
expect_exact "additional module is appended safely" 0 "$expected_with_terminal" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" resolve --profile shell.minimal --add terminal.ghostty --platform macos
expect_contains "exclusive group conflict fails" 3 "share exclusive group terminal.primary" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" resolve --modules terminal.ghostty,terminal.wezterm --platform macos
expect_contains "unsupported platform fails" 3 "does not support platform debian" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" resolve --modules terminal.ghostty --platform debian
expect_contains "unknown module fails" 3 "unknown module shell.unknown" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" resolve --modules shell.unknown --platform debian
expect_contains "dependency cycle fails validation" 3 "dependency cycle includes" env DOTFILES_SOURCE_DIR="${FIXTURES}/cycle" "$CLI" catalog validate
expect_contains "missing dependency fails validation" 3 "depends on unknown module shell.missing" env DOTFILES_SOURCE_DIR="${FIXTURES}/missing-dependency" "$CLI" catalog validate
expect_contains "unknown manifest field fails validation" 3 "unsupported field unexpected" env DOTFILES_SOURCE_DIR="${FIXTURES}/unknown-field" "$CLI" catalog validate
expect_contains "category path mismatch fails validation" 3 "must be stored at .chezmoidata/modules/shell/alpha.toml" env DOTFILES_SOURCE_DIR="${FIXTURES}/invalid-layout" "$CLI" catalog validate
expect_contains "usage errors use status 2" 2 "unknown command unknown" "$CLI" unknown
expect_contains "missing chezmoi uses status 4" 4 "chezmoi is required" env DOTFILES_CHEZMOI_BIN=does-not-exist "$CLI" catalog validate

if [ "$failures" -ne 0 ]; then
    printf '%s of %s checks failed\n' "$failures" "$checks" >&2
    exit 1
fi

printf '%s checks passed\n' "$checks"
