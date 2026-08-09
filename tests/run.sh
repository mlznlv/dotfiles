#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
CLI="${PROJECT_ROOT}/bin/dotfiles"
FIXTURE_DEFINITIONS="${PROJECT_ROOT}/tests/fixtures"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")

cleanup() {
    rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

stage_fixture() {
    fixture_name=$1
    fixture_source="${FIXTURE_DEFINITIONS}/${fixture_name}/catalog"
    fixture_target="${TEST_ROOT}/${fixture_name}/.chezmoidata"

    mkdir -p "${fixture_target}"
    cp -R "${fixture_source}/." "${fixture_target}/"
}

for fixture_name in cycle invalid-identifier invalid-layout missing-dependency unknown-field valid schema2-valid schema2-collision schema2-unsafe schema2-platform schema2-source schema2-unknown-schema schema2-unknown-provider; do
    stage_fixture "${fixture_name}"
done

FIXTURES="${TEST_ROOT}"
VALID="${FIXTURES}/valid"
PROVIDER_BIN="${TEST_ROOT}/provider-bin"
PROVIDER_LOG="${TEST_ROOT}/provider.log"

mkdir -p "${PROVIDER_BIN}"
for provider in brew mise; do
    printf '%s\n' \
        '#!/bin/sh' \
        'printf "%s\n" "$0 $*" >> "${DOTFILES_PROVIDER_LOG}"' \
        'exit 97' > "${PROVIDER_BIN}/${provider}"
    chmod +x "${PROVIDER_BIN}/${provider}"
done
export DOTFILES_PROVIDER_LOG="${PROVIDER_LOG}"
export PATH="${PROVIDER_BIN}:${PATH}"

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
expect_exact "production catalog validates" 0 "catalog valid: 3 modules, 1 profiles" "$CLI" catalog validate
expect_contains "production module list exposes Zsh" 0 "shell.zsh" "$CLI" module list --platform macos
expect_contains "production module list exposes Starship" 0 "prompt.starship" "$CLI" module list --platform debian
expect_contains "production profile list exposes minimal shell" 0 "shell.minimal" "$CLI" profile list --platform debian
expect_contains "production module show exposes dependency" 0 "depends: shell.zsh" "$CLI" module show prompt.starship
expect_contains "production profile show exposes composition" 0 "modules: shell.zsh,shell.zsh.autosuggestions,prompt.starship" "$CLI" profile show shell.minimal
expect_exact "production profile resolves on macOS" 0 "$expected_profile" "$CLI" resolve --profile shell.minimal --platform macos
expect_exact "production profile resolves on Debian" 0 "$expected_profile" "$CLI" resolve --profile shell.minimal --platform debian
expect_exact "production explicit modules resolve deterministically" 0 "$expected_profile" "$CLI" resolve --modules shell.zsh.autosuggestions,prompt.starship --platform debian
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
expect_contains "declared module conflict fails" 3 "module terminal.wezterm conflicts with shell.zsh" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" resolve --modules shell.zsh,terminal.wezterm --platform macos
expect_contains "dependency cycle fails validation" 3 "dependency cycle includes" env DOTFILES_SOURCE_DIR="${FIXTURES}/cycle" "$CLI" catalog validate
expect_contains "invalid identifier fails validation" 3 "contains invalid identifier Shell.invalid" env DOTFILES_SOURCE_DIR="${FIXTURES}/invalid-identifier" "$CLI" catalog validate
expect_contains "missing dependency fails validation" 3 "depends on unknown module shell.missing" env DOTFILES_SOURCE_DIR="${FIXTURES}/missing-dependency" "$CLI" catalog validate
expect_contains "unknown manifest field fails validation" 3 "unsupported field unexpected" env DOTFILES_SOURCE_DIR="${FIXTURES}/unknown-field" "$CLI" catalog validate
expect_contains "category path mismatch fails validation" 3 "must be stored at .chezmoidata/modules/shell/alpha.toml" env DOTFILES_SOURCE_DIR="${FIXTURES}/invalid-layout" "$CLI" catalog validate
expect_exact "schema 2 validates provider and nested chezmoi data" 0 "catalog valid: 1 modules, 0 profiles" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-valid" "$CLI" catalog validate
expect_contains "unsafe provider identifier fails" 3 "unsafe provider identifier --formula" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-unsafe" "$CLI" catalog validate
expect_contains "Homebrew requires macOS support" 3 "declares Homebrew packages without macos support" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-platform" "$CLI" catalog validate
expect_contains "chezmoi traversal fails" 3 "unsafe chezmoi source home/../dot_zshrc" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-source" "$CLI" catalog validate
expect_contains "Homebrew ownership collision fails on macOS" 3 "duplicate ownership key homebrew:package:shared" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-collision" "$CLI" resolve --modules shell.alpha,shell.beta --platform macos
expect_contains "mise ownership collision fails on Debian" 3 "duplicate ownership key mise:package:shared" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-collision" "$CLI" resolve --modules shell.alpha,shell.beta --platform debian
expect_contains "rendered target collision is normalized" 3 "duplicate ownership key chezmoi:target:.zshrc" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-collision" "$CLI" resolve --modules shell.alpha,shell.beta --platform debian
expect_contains "mise tool ownership collision fails" 3 "duplicate ownership key mise:tool:shared-tool" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-collision" "$CLI" resolve --modules shell.alpha,shell.beta --platform debian
expect_contains "unknown module schema fails" 3 "unsupported schema 3" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-unknown-schema" "$CLI" catalog validate
expect_contains "unknown schema 2 provider fails" 3 "unsupported field providers.macos.apt.packages" env DOTFILES_SOURCE_DIR="${FIXTURES}/schema2-unknown-provider" "$CLI" catalog validate
expect_contains "usage errors use status 2" 2 "unknown command unknown" "$CLI" unknown
expect_contains "missing chezmoi uses status 4" 4 "chezmoi is required" env DOTFILES_CHEZMOI_BIN=does-not-exist "$CLI" catalog validate

if [ ! -e "${PROVIDER_LOG}" ]; then
    STATUS=0
    OUTPUT=
    pass "released commands invoke no package provider"
else
    STATUS=97
    OUTPUT="a package provider was invoked"
    fail "released commands invoke no package provider"
fi

if [ "$failures" -ne 0 ]; then
    printf '%s of %s checks failed\n' "$failures" "$checks" >&2
    exit 1
fi

printf '%s checks passed\n' "$checks"
