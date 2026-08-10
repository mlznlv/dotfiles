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

for fixture_name in cycle invalid-identifier invalid-layout missing-dependency unknown-field valid prerequisites-valid prerequisite-invalid-identifiers prerequisite-control-character prerequisite-unsupported-platform prerequisite-unknown-table prerequisite-unknown-field provider-field source-collision source-unsafe unsupported-schema; do
    stage_fixture "${fixture_name}"
done

FIXTURES="${TEST_ROOT}"
VALID="${FIXTURES}/valid"
PROBE_BIN="${TEST_ROOT}/probe-bin"
PROBE_LOG="${TEST_ROOT}/probe.log"

mkdir -p "${PROBE_BIN}"
for probe in brew mise apt apt-get dnf yum pacman apk installer zsh starship; do
    printf '%s\n' \
        '#!/bin/sh' \
        'printf "%s\n" "$0 $*" >> "${DOTFILES_PROBE_LOG}"' \
        'exit 97' > "${PROBE_BIN}/${probe}"
    chmod +x "${PROBE_BIN}/${probe}"
done
export DOTFILES_PROBE_LOG="${PROBE_LOG}"
export PATH="${PROBE_BIN}:${PATH}"

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
expect_exact "production catalog validates" 0 "catalog valid: 3 modules, 1 profile" "$CLI" catalog validate
expect_contains "production module list exposes Zsh" 0 "shell.zsh" "$CLI" module list --platform macos
expect_contains "production module list exposes Starship" 0 "prompt.starship" "$CLI" module list --platform debian
expect_contains "production profile list exposes minimal shell" 0 "shell.minimal" "$CLI" profile list --platform debian
expect_contains "production module show exposes dependency" 0 "depends: shell.zsh" "$CLI" module show shell.zsh.autosuggestions
expect_contains "production profile show exposes composition" 0 "modules: shell.zsh,shell.zsh.autosuggestions,prompt.starship" "$CLI" profile show shell.minimal
expect_exact "production profile resolves on macOS" 0 "$expected_profile" "$CLI" resolve --profile shell.minimal --platform macos
expect_exact "production profile resolves on Debian" 0 "$expected_profile" "$CLI" resolve --profile shell.minimal --platform debian
expect_exact "production explicit modules resolve deterministically" 0 "$expected_profile" "$CLI" resolve --modules shell.zsh.autosuggestions,prompt.starship --platform debian
expect_exact "Starship resolves independently" 0 "prompt.starship" "$CLI" resolve --modules prompt.starship --platform debian
if [ -f "${PROJECT_ROOT}/.chezmoidata/modules/shell/zsh/zsh.toml" ] && \
   [ -f "${PROJECT_ROOT}/.chezmoidata/modules/shell/zsh/autosuggestions.toml" ] && \
   [ ! -e "${PROJECT_ROOT}/.chezmoidata/modules/shell/zsh.toml" ] && \
   [ ! -e "${PROJECT_ROOT}/.chezmoidata/modules/shell/zsh-autosuggestions.toml" ]; then
    STATUS=0
    OUTPUT=
    pass "production Zsh manifests use hierarchical layout only"
else
    STATUS=1
    OUTPUT="production Zsh manifest layout is incorrect"
    fail "production Zsh manifests use hierarchical layout only"
fi
if [ -f "${PROJECT_ROOT}/docs/modules/shell/zsh/zsh.md" ] && \
   [ -f "${PROJECT_ROOT}/docs/modules/shell/zsh/autosuggestions.md" ] && \
   [ ! -e "${PROJECT_ROOT}/docs/modules/shell/zsh.md" ] && \
   [ ! -e "${PROJECT_ROOT}/docs/modules/shell/zsh-autosuggestions.md" ]; then
    STATUS=0
    OUTPUT=
    pass "production Zsh documentation uses hierarchical layout only"
else
    STATUS=1
    OUTPUT="production Zsh documentation layout is incorrect"
    fail "production Zsh documentation uses hierarchical layout only"
fi
if ! find "${PROJECT_ROOT}/.chezmoidata/modules" -type f -name '*.toml' -exec grep -E -l 'providers|homebrew|mise' {} + | grep -q .; then
    STATUS=0
    OUTPUT=
    pass "production modules contain no provider fields"
else
    STATUS=1
    OUTPUT="a production provider field remains"
    fail "production modules contain no provider fields"
fi
expect_exact "fixture catalog validates" 0 "catalog valid: 5 modules, 1 profile" env DOTFILES_SOURCE_DIR="$VALID" "$CLI" catalog validate
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
expect_contains "chezmoi traversal fails" 3 "unsafe chezmoi source home/../dot_zshrc" env DOTFILES_SOURCE_DIR="${FIXTURES}/source-unsafe" "$CLI" catalog validate
expect_contains "unknown module schema fails" 3 "schema must be 1" env DOTFILES_SOURCE_DIR="${FIXTURES}/unsupported-schema" "$CLI" catalog validate
expect_exact "schema 1 validates every prerequisite kind and optional arrays" 0 "catalog valid: 3 modules, 0 profiles" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisites-valid" "$CLI" catalog validate
expect_exact "schema 1 prerequisite resolution remains read-only" 0 "shell.alpha" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisites-valid" "$CLI" resolve --modules shell.alpha --platform macos
expect_contains "unsafe command path fails" 3 "unsafe command identifier ./zsh" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "unsafe command arguments fail" 3 "unsafe command identifier zsh --version" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "unsafe command URL fails" 3 "unsafe command identifier https://example.com/zsh" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "unsafe command shell syntax fails" 3 "unsafe command identifier zsh;id" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "duplicate command fails" 3 "macos commands contains duplicate identifier duplicate" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "unsafe application identifier fails" 3 "unsafe application identifier bad app" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "unsafe application URL fails" 3 "unsafe application identifier https://example.com/app" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "unsafe application shell syntax fails" 3 "unsafe application identifier app;id" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "duplicate application fails" 3 "macos applications contains duplicate identifier duplicate.app" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact without root fails" 3 "artifact locator without root missing-root" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "unknown artifact root fails" 3 "unknown artifact root unknown" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "unsafe artifact locator fails" 3 "unsafe artifact locator share:/absolute" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact traversal fails" 3 "unsafe artifact locator share:../traversal" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact empty segment fails" 3 "unsafe artifact locator share:path//empty" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact dot segment fails" 3 "unsafe artifact locator share:." env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact dot-dot segment fails" 3 "unsafe artifact locator share:.." env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact glob fails" 3 "unsafe artifact locator share:path/*" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact variable fails" 3 'unsafe artifact locator share:$HOME/file' env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact tilde fails" 3 "unsafe artifact locator share:~/file" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact URL fails" 3 "unknown artifact root https" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact whitespace fails" 3 "unsafe artifact locator share:path with-space" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact shell syntax fails" 3 "unsafe artifact locator share:path;id" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "duplicate artifact fails" 3 "macos artifacts contains duplicate identifier share:duplicate/file" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-invalid-identifiers" "$CLI" catalog validate
expect_contains "artifact control character fails" 3 "malformed module record" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-control-character" "$CLI" catalog validate
expect_contains "unsupported prerequisite platform fails" 3 "declares macos prerequisites without macos support" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-unsupported-platform" "$CLI" catalog validate
expect_contains "unknown prerequisite table fails" 3 "unsupported field prerequisites.windows.commands" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-unknown-table" "$CLI" catalog validate
expect_contains "unknown prerequisite field fails" 3 "unsupported field prerequisites.debian.packages" env DOTFILES_SOURCE_DIR="${FIXTURES}/prerequisite-unknown-field" "$CLI" catalog validate
expect_contains "provider fields fail" 3 "unsupported field providers.macos.homebrew.packages" env DOTFILES_SOURCE_DIR="${FIXTURES}/provider-field" "$CLI" catalog validate
expect_contains "rendered target collision is normalized" 3 "duplicate ownership key chezmoi:target:.zshrc" env DOTFILES_SOURCE_DIR="${FIXTURES}/source-collision" "$CLI" resolve --modules shell.alpha,shell.beta --platform debian
expect_contains "usage errors use status 2" 2 "unknown command unknown" "$CLI" unknown
expect_contains "missing chezmoi uses status 4" 4 "chezmoi is required" env DOTFILES_CHEZMOI_BIN=does-not-exist "$CLI" catalog validate

if [ ! -e "${PROBE_LOG}" ]; then
    STATUS=0
    OUTPUT=
    pass "validation and resolution invoke no provider, installer, or prerequisite"
else
    STATUS=97
    OUTPUT="a provider, installer, or prerequisite was invoked"
    fail "validation and resolution invoke no provider, installer, or prerequisite"
fi

if [ "$failures" -ne 0 ]; then
    printf '%s of %s checks failed\n' "$failures" "$checks" >&2
    exit 1
fi

printf '%s checks passed\n' "$checks"
