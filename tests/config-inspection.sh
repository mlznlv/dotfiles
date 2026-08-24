#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
CLI="${PROJECT_ROOT}/bin/dotfiles"
TEST_PARENT=${TMPDIR:-/tmp}
TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-config-inspection-tests.XXXXXX")

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

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

run_cli "${TEST_ROOT}/roots/help-missing" "$(new_home help)" config inspect --help
check_status 'inspect help succeeds without state' 0
check_contains 'inspect help lists exact synopsis' 'dotfiles config inspect [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]'
run_cli "${TEST_ROOT}/roots/help-missing" "${TEST_ROOT}/homes/help" config doctor -h
check_status 'doctor help succeeds without state' 0
check_contains 'doctor help lists exact synopsis' 'dotfiles config doctor [--platform macos|debian]'
check_not_contains 'help keeps cache reset unavailable' 'config cache reset'
[ ! -e "${TEST_ROOT}/roots/help-missing" ] && pass 'inspection help creates no state root' || { STATUS=1; OUTPUT='root created'; fail 'inspection help creates no state root'; }

MISSING_ROOT="${TEST_ROOT}/roots/missing"
MISSING_HOME=$(new_home missing)
for arguments in \
    '--profile shell.minimal --profile shell.minimal --platform debian' \
    '--modules shell.zsh --modules shell.zsh --platform debian' \
    '--profile shell.minimal --modules shell.zsh --platform debian' \
    '--profile shell.minimal --add shell.zsh --add prompt.starship --platform debian' \
    '--profile shell.minimal --platform debian --platform macos' \
    '--profile --platform debian' \
    '--modules --platform debian' \
    '--add --platform debian' \
    '--platform --profile shell.minimal' \
    '--profile shell.minimal --yes' \
    '--unknown' \
    'positional'; do
    # Intentional word splitting exercises the public argument parser.
    # shellcheck disable=SC2086
    run_cli "$MISSING_ROOT" "$MISSING_HOME" config inspect $arguments
    check_status "inspect syntax is status 2 before state access: $arguments" 2
done

for arguments in \
    '--platform debian --platform macos' \
    '--platform --profile' \
    '--profile shell.minimal' \
    '--modules shell.zsh' \
    '--add shell.zsh' \
    '--yes' \
    '--unknown' \
    'positional'; do
    # shellcheck disable=SC2086
    run_cli "$MISSING_ROOT" "$MISSING_HOME" config doctor $arguments
    check_status "doctor rejects non-platform syntax: $arguments" 2
done
run_cli "$MISSING_ROOT" "$MISSING_HOME" config inspect --modules ''
check_status 'inspect rejects an empty option value before state access' 2
run_cli "$MISSING_ROOT" "$MISSING_HOME" config doctor --platform ''
check_status 'doctor rejects an empty platform value before state access' 2
[ ! -e "$MISSING_ROOT" ] && pass 'syntax failures create no state root' || { STATUS=1; OUTPUT='root created'; fail 'syntax failures create no state root'; }

run_cli "$MISSING_ROOT" "$MISSING_HOME" config inspect --platform debian
check_status 'no-base inspect requires saved state' 3
check_contains 'missing inspect gives explicit-save guidance' 'Run dotfiles config set or pass --profile or --modules.'
assert_no_summary 'failed local inspect emits no partial summary'
run_cli "$MISSING_ROOT" "$MISSING_HOME" config inspect --add prompt.starship --platform debian
check_status 'add-only inspect reaches saved state' 3
run_cli "$MISSING_ROOT" "$MISSING_HOME" config doctor --platform debian
check_status 'missing-state doctor is unhealthy' 3
check_contains 'missing-state doctor names both save commands' 'Run dotfiles config set or dotfiles config interactive.'
assert_no_summary 'missing-state doctor emits no healthy summary'
run_command env DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT=doctor XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" resolve --platform debian
check_status 'public environment cannot select private doctor diagnostics' 3
check_contains 'consumer keeps consumer-specific recovery under a poisoned environment' 'or pass --profile or --modules'
[ ! -e "$MISSING_ROOT" ] && pass 'missing diagnosis creates no root, directory, lock, snapshot, temporary file, or cache' || { STATUS=1; OUTPUT='root created'; fail 'missing diagnosis is zero-mutation'; }

PROFILE_ROOT=$(new_root profile)
PROFILE_HOME=$(new_home profile)
write_state "$PROFILE_ROOT" "$PROFILE_BODY"
PROFILE_BEFORE=$(state_snapshot "$PROFILE_ROOT")
HOME_BEFORE=$(tree_snapshot "$PROFILE_HOME")
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --platform debian
check_status 'saved profile inspection succeeds on Debian' 0
check_equal 'saved profile inspection output is exact' "$STDOUT" "$PROFILE_DEBIAN_OUTPUT"
check_equal 'successful inspect writes no stderr' "$STDERR" ''
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --platform macos
check_equal 'saved profile inspection is exact on macOS' "$STDOUT" "$PROFILE_MACOS_OUTPUT"
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config doctor --platform debian
check_equal 'healthy profile doctor output is exact on Debian' "$STDOUT" 'Local selection file: healthy
Schema: 1
Composition for debian: valid'
check_equal 'healthy doctor writes no stderr' "$STDERR" ''
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config doctor --platform macos
check_equal 'healthy profile doctor output is exact on macOS' "$STDOUT" 'Local selection file: healthy
Schema: 1
Composition for macos: valid'
check_equal 'profile inspect and doctor preserve bytes, identity, mode, modification time, and tree' "$(state_snapshot "$PROFILE_ROOT")" "$PROFILE_BEFORE"
check_equal 'profile inspect and doctor leave managed HOME unchanged' "$(tree_snapshot "$PROFILE_HOME")" "$HOME_BEFORE"

MODULE_ROOT=$(new_root modules)
MODULE_HOME=$(new_home modules)
write_state "$MODULE_ROOT" "$MODULE_BODY"
MODULE_BEFORE=$(state_snapshot "$MODULE_ROOT")
run_cli "$MODULE_ROOT" "$MODULE_HOME" config inspect --platform macos
check_equal 'ordered module inspection output is exact' "$STDOUT" "$MODULE_MACOS_OUTPUT"
run_cli "$MODULE_ROOT" "$MODULE_HOME" config doctor --platform macos
check_equal 'healthy module doctor output is exact' "$STDOUT" 'Local selection file: healthy
Schema: 1
Composition for macos: valid'
run_cli "$MODULE_ROOT" "$MODULE_HOME" config inspect --platform debian
check_equal 'ordered module inspection is exact on Debian' "$STDOUT" "${MODULE_MACOS_OUTPUT//macos/debian}"
run_cli "$MODULE_ROOT" "$MODULE_HOME" config doctor --platform debian
check_equal 'healthy module doctor output is exact on Debian' "$STDOUT" 'Local selection file: healthy
Schema: 1
Composition for debian: valid'
check_equal 'module inspect and doctor preserve state metadata and tree' "$(state_snapshot "$MODULE_ROOT")" "$MODULE_BEFORE"

run_cli "$MISSING_ROOT" "$MISSING_HOME" config inspect --profile shell.minimal --platform debian
check_status 'explicit profile inspection bypasses missing state' 0
check_equal 'explicit profile uses invocation source and exact base' "$STDOUT" "${PROFILE_DEBIAN_OUTPUT/Selection source: local/Selection source: invocation}"
run_cli "$MISSING_ROOT" "$MISSING_HOME" config inspect --modules prompt.starship,shell.zsh --add shell.zsh.autosuggestions --platform macos
check_status 'explicit modules inspection bypasses missing state' 0
check_equal 'explicit modules preserve invocation base and additions' "$STDOUT" "${MODULE_MACOS_OUTPUT/Selection source: local/Selection source: invocation}"
[ ! -e "$MISSING_ROOT" ] && pass 'explicit inspection never derives or creates local state' || { STATUS=1; OUTPUT='root created'; fail 'explicit inspection never derives or creates local state'; }

ADDITIONAL_ROOT=$(new_root additional)
ADDITIONAL_HOME=$(new_home additional)
write_state "$ADDITIONAL_ROOT" "$ADDITIONAL_BODY"
ADDITIONAL_BEFORE=$(state_snapshot "$ADDITIONAL_ROOT")
run_cli "$ADDITIONAL_ROOT" "$ADDITIONAL_HOME" config inspect --add shell.zsh.autosuggestions --platform debian
check_status 'invocation addition appends to saved additions' 0
check_equal 'local-plus-invocation source and effective addition order are exact' "$STDOUT" 'Selection source: local plus invocation additions
Base: shell.zsh
Additional modules: prompt.starship,shell.zsh.autosuggestions
Resolved modules for debian:
  shell.zsh
  prompt.starship
  shell.zsh.autosuggestions'
check_equal 'inspection additions are never persisted' "$(state_snapshot "$ADDITIONAL_ROOT")" "$ADDITIONAL_BEFORE"

INVALID_ROOT=$(new_root invalid-bypass)
INVALID_HOME=$(new_home invalid-bypass)
write_state "$INVALID_ROOT" 'private-invalid-state-must-not-be-read'
INVALID_BEFORE=$(state_snapshot "$INVALID_ROOT")
run_cli "$INVALID_ROOT" "$INVALID_HOME" config inspect --modules prompt.starship --platform debian
check_status 'explicit inspect bypasses invalid local state' 0
check_equal 'invalid-state bypass output matches missing-state bypass' "$STDOUT" 'Selection source: invocation
Base: prompt.starship
Additional modules: none
Resolved modules for debian:
  prompt.starship'
check_not_contains 'explicit bypass never exposes invalid state bytes' 'private-invalid-state-must-not-be-read'
check_equal 'explicit bypass leaves invalid state untouched' "$(state_snapshot "$INVALID_ROOT")" "$INVALID_BEFORE"

ISOLATED="${TEST_ROOT}/isolated-project"
mkdir -p "$ISOLATED/bin" "$ISOLATED/lib"
cp "$CLI" "$ISOLATED/bin/dotfiles"
cp "${PROJECT_ROOT}/lib/catalog-records.tmpl" "${PROJECT_ROOT}/lib/catalog.awk" "$ISOLATED/lib/"
run_command env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$ISOLATED/bin/dotfiles" config inspect --modules prompt.starship --platform debian
check_status 'explicit inspect works without the config-state component' 0
check_equal 'component-free explicit inspect remains exact' "$STDOUT" 'Selection source: invocation
Base: prompt.starship
Additional modules: none
Resolved modules for debian:
  prompt.starship'
run_command env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$ISOLATED/bin/dotfiles" config inspect --platform debian
check_status 'local inspect requires the config-state component' 4
run_command env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$ISOLATED/bin/dotfiles" config doctor --platform debian
check_status 'doctor requires the config-state component' 4

cp "${PROJECT_ROOT}/lib/config-state.sh" "$ISOLATED/lib/config-state.sh"
rm -f "$ISOLATED/lib/catalog.awk"
run_command env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" \
    "$ISOLATED/bin/dotfiles" config doctor --platform debian
check_status 'doctor requires the catalog component' 4
assert_no_summary 'missing catalog component emits no healthy summary'

run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --modules shell.zsh,shell.zsh --platform debian
check_status 'duplicate explicit input is invalid composition' 3
assert_no_summary 'duplicate explicit failure emits no inspect summary'
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --modules shell.unknown --platform debian
check_status 'unknown explicit identifier is invalid composition' 3
assert_no_summary 'unknown identifier failure emits no inspect summary'
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --modules terminal.ghostty --platform debian
check_status 'unsupported module/platform is invalid composition' 3
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --platform linux
check_status 'unsupported inspect platform is status 3' 3
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config doctor --platform linux
check_status 'unsupported doctor platform is status 3' 3

VALID_FIXTURE=$(stage_fixture valid)
CYCLE_FIXTURE=$(stage_fixture cycle)
COLLISION_FIXTURE=$(stage_fixture source-collision)
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config inspect --modules terminal.ghostty,terminal.wezterm --platform macos
check_status 'inspect rejects exclusive-group conflicts' 3
assert_no_summary 'exclusive-group failure emits no inspect summary'
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config inspect --modules shell.zsh,terminal.wezterm --platform macos
check_status 'inspect rejects declared conflicts' 3
run_command env DOTFILES_SOURCE_DIR="$CYCLE_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config inspect --modules shell.alpha --platform debian
check_status 'inspect rejects dependency cycles' 3
run_command env DOTFILES_SOURCE_DIR="$COLLISION_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config inspect --modules shell.alpha,shell.beta --platform debian
check_status 'inspect rejects rendered-target ownership collisions' 3

DOCTOR_CONFLICT_ROOT=$(new_root doctor-conflict)
write_state "$DOCTOR_CONFLICT_ROOT" 'schema = 1

[selection]
modules = ["terminal.ghostty", "terminal.wezterm"]
additional_modules = []'
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$DOCTOR_CONFLICT_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config doctor --platform macos
check_status 'doctor rejects saved exclusive-group conflicts' 3
assert_no_summary 'saved conflict diagnosis emits no healthy summary'
DOCTOR_CYCLE_ROOT=$(new_root doctor-cycle)
write_state "$DOCTOR_CYCLE_ROOT" 'schema = 1

[selection]
modules = ["shell.alpha"]
additional_modules = []'
run_command env DOTFILES_SOURCE_DIR="$CYCLE_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$DOCTOR_CYCLE_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config doctor --platform debian
check_status 'doctor rejects saved dependency cycles' 3
DOCTOR_COLLISION_ROOT=$(new_root doctor-collision)
write_state "$DOCTOR_COLLISION_ROOT" 'schema = 1

[selection]
modules = ["shell.alpha", "shell.beta"]
additional_modules = []'
run_command env DOTFILES_SOURCE_DIR="$COLLISION_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$DOCTOR_COLLISION_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config doctor --platform debian
check_status 'doctor rejects saved rendered-target ownership collisions' 3

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

invalid_doctor_case 'doctor rejects malformed TOML without mutation' 'not toml'
invalid_doctor_case 'doctor rejects non-canonical comments without mutation' 'schema = 1

[selection]
profile = "shell.minimal"
additional_modules = [] # comment'
invalid_doctor_case 'doctor rejects unknown schema without mutation' 'schema = 2

[selection]
profile = "shell.minimal"
additional_modules = []'
invalid_doctor_case 'doctor rejects unknown fields without mutation' 'schema = 1

[selection]
profile = "shell.minimal"
additional_modules = []
unknown = true'
invalid_doctor_case 'doctor rejects both bases without mutation' 'schema = 1

[selection]
profile = "shell.minimal"
modules = ["shell.zsh"]
additional_modules = []'
invalid_doctor_case 'doctor rejects missing base without mutation' 'schema = 1

[selection]
additional_modules = []'
invalid_doctor_case 'doctor rejects empty module base without mutation' 'schema = 1

[selection]
modules = []
additional_modules = []'
invalid_doctor_case 'doctor rejects duplicate identifiers without mutation' 'schema = 1

[selection]
modules = ["shell.zsh", "shell.zsh"]
additional_modules = []'
invalid_doctor_case 'doctor rejects catalog drift without mutation' 'schema = 1

[selection]
modules = ["shell.unknown"]
additional_modules = []'

MISSING_DIRECTORY_ROOT=$(new_root missing-directory)
run_cli "$MISSING_DIRECTORY_ROOT" "$(new_home missing-directory)" config doctor --platform debian
check_status 'doctor rejects a missing dedicated directory' 3
check_contains 'missing directory diagnosis recommends saving' 'config interactive'
[ ! -e "$MISSING_DIRECTORY_ROOT/dotfiles" ] && pass 'missing-directory diagnosis creates nothing' || { STATUS=1; OUTPUT='directory created'; fail 'missing-directory diagnosis creates nothing'; }

MISSING_FILE_ROOT=$(new_root missing-file)
mkdir "$MISSING_FILE_ROOT/dotfiles"
chmod 700 "$MISSING_FILE_ROOT/dotfiles"
MISSING_FILE_BEFORE=$(tree_snapshot "$MISSING_FILE_ROOT")
run_cli "$MISSING_FILE_ROOT" "$(new_home missing-file)" config doctor --platform debian
check_status 'doctor rejects a missing state file' 3
check_equal 'missing-file diagnosis preserves root tree' "$(tree_snapshot "$MISSING_FILE_ROOT")" "$MISSING_FILE_BEFORE"

HOME_FALLBACK=$(new_home home-fallback)
mkdir "$HOME_FALLBACK/.config"
write_state "$HOME_FALLBACK/.config" "$PROFILE_BODY"
run_cli_without_xdg "$HOME_FALLBACK" config doctor --platform debian
check_equal 'doctor uses HOME fallback when XDG is unset' "$STDOUT" 'Local selection file: healthy
Schema: 1
Composition for debian: valid'
run_command env XDG_CONFIG_HOME= HOME="$HOME_FALLBACK" "$CLI" config inspect --platform debian
check_equal 'inspect uses HOME fallback when XDG is empty' "$STDOUT" "$PROFILE_DEBIAN_OUTPUT"
XDG_PRECEDENCE=$(new_root xdg-precedence)
write_state "$XDG_PRECEDENCE" "$MODULE_BODY"
run_cli "$XDG_PRECEDENCE" "$HOME_FALLBACK" config inspect --platform debian
check_equal 'non-empty XDG selection takes precedence over HOME fallback' "$STDOUT" "${MODULE_MACOS_OUTPUT//macos/debian}"
run_command env XDG_CONFIG_HOME=relative HOME="$HOME_FALLBACK" "$CLI" config doctor --platform debian
check_status 'invalid non-empty XDG never falls back to HOME' 3
check_not_contains 'invalid XDG diagnostic hides raw invalid value' 'relative'
check_contains 'invalid XDG diagnostic uses stable origin token' '$XDG_CONFIG_HOME'

run_command env XDG_CONFIG_HOME="${PROJECT_ROOT}/.forbidden-inspection" HOME="$MISSING_HOME" "$CLI" config doctor --platform debian
check_status 'repository-contained doctor root is rejected' 3
[ ! -e "${PROJECT_ROOT}/.forbidden-inspection" ] && pass 'repository-contained diagnosis creates nothing' || { STATUS=1; OUTPUT='repository path created'; fail 'repository-contained diagnosis creates nothing'; }

SYSTEM_ROOT=
for candidate in /private/tmp /var/tmp /tmp; do
    if [ -d "$candidate" ] && [ ! -L "$candidate" ] && [ "$(dotfiles_config_stat_owner "$candidate")" != "$(id -u)" ]; then
        SYSTEM_ROOT=$candidate
        break
    fi
done
if [ -n "$SYSTEM_ROOT" ]; then
    run_cli "$SYSTEM_ROOT" "$MISSING_HOME" config doctor --platform debian
    check_status 'doctor rejects a configuration root owned by another user' 3
else
    STATUS=0
    OUTPUT=
    pass 'wrong-owner doctor fixture unavailable for this user'
fi

SYMLINK_TARGET=$(new_root symlink-target)
write_state "$SYMLINK_TARGET" "$PROFILE_BODY"
ln -s "$SYMLINK_TARGET" "${TEST_ROOT}/roots/symlink-root"
run_cli "${TEST_ROOT}/roots/symlink-root" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects symlinked root' 3
SYMLINK_DIRECTORY_ROOT=$(new_root symlink-directory)
ln -s "$SYMLINK_TARGET/dotfiles" "$SYMLINK_DIRECTORY_ROOT/dotfiles"
run_cli "$SYMLINK_DIRECTORY_ROOT" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects symlinked dedicated directory' 3
SYMLINK_FILE_ROOT=$(new_root symlink-file)
mkdir "$SYMLINK_FILE_ROOT/dotfiles"
chmod 700 "$SYMLINK_FILE_ROOT/dotfiles"
ln -s "$SYMLINK_TARGET/dotfiles/active-selection.toml" "$SYMLINK_FILE_ROOT/dotfiles/active-selection.toml"
run_cli "$SYMLINK_FILE_ROOT" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects symlinked state file' 3
run_cli "$SYMLINK_FILE_ROOT" "$MISSING_HOME" config inspect --modules prompt.starship --platform debian
check_status 'explicit inspect bypasses symlinked local state' 0
check_equal 'symlink-state bypass remains byte-identical' "$STDOUT" 'Selection source: invocation
Base: prompt.starship
Additional modules: none
Resolved modules for debian:
  prompt.starship'

WRONG_ROOT_TYPE="${TEST_ROOT}/roots/wrong-root-type"
printf 'not a directory\n' > "$WRONG_ROOT_TYPE"
run_cli "$WRONG_ROOT_TYPE" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects wrong root type' 3
WRONG_DIRECTORY_ROOT=$(new_root wrong-directory-type)
printf 'not a directory\n' > "$WRONG_DIRECTORY_ROOT/dotfiles"
run_cli "$WRONG_DIRECTORY_ROOT" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects wrong dedicated-directory type' 3
WRONG_FILE_ROOT=$(new_root wrong-file-type)
mkdir "$WRONG_FILE_ROOT/dotfiles" "$WRONG_FILE_ROOT/dotfiles/active-selection.toml"
chmod 700 "$WRONG_FILE_ROOT/dotfiles"
run_cli "$WRONG_FILE_ROOT" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects wrong state-file type' 3

WRONG_DIRECTORY_MODE_ROOT=$(new_root wrong-directory-mode)
write_state "$WRONG_DIRECTORY_MODE_ROOT" "$PROFILE_BODY"
chmod 755 "$WRONG_DIRECTORY_MODE_ROOT/dotfiles"
run_cli "$WRONG_DIRECTORY_MODE_ROOT" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects unsafe dedicated-directory mode' 3
WRONG_FILE_MODE_ROOT=$(new_root wrong-file-mode)
write_state "$WRONG_FILE_MODE_ROOT" "$PROFILE_BODY"
chmod 644 "$WRONG_FILE_MODE_ROOT/dotfiles/active-selection.toml"
run_cli "$WRONG_FILE_MODE_ROOT" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects unsafe state-file mode' 3
HARD_LINK_ROOT=$(new_root hard-link)
write_state "$HARD_LINK_ROOT" "$PROFILE_BODY"
ln "$HARD_LINK_ROOT/dotfiles/active-selection.toml" "$HARD_LINK_ROOT/dotfiles/second-link"
HARD_LINK_BEFORE=$(state_snapshot "$HARD_LINK_ROOT")
run_cli "$HARD_LINK_ROOT" "$MISSING_HOME" config doctor --platform debian
check_status 'doctor rejects hard-linked state' 3
check_equal 'hard-link diagnosis preserves both links' "$(state_snapshot "$HARD_LINK_ROOT")" "$HARD_LINK_BEFORE"

LOCK_ROOT=$(new_root lock)
LOCK_HOME=$(new_home lock)
write_state "$LOCK_ROOT" "$PROFILE_BODY"
mkdir "$LOCK_ROOT/dotfiles/active-selection.lock"
chmod 700 "$LOCK_ROOT/dotfiles/active-selection.lock"
printf 'unrelated\n' > "$LOCK_ROOT/dotfiles/unrelated"
LOCK_BEFORE=$(state_snapshot "$LOCK_ROOT")
run_cli "$LOCK_ROOT" "$LOCK_HOME" config doctor --platform debian
check_status 'doctor ignores an adjacent writer lock' 0
check_equal 'doctor reports healthy while a lock exists' "$STDOUT" 'Local selection file: healthy
Schema: 1
Composition for debian: valid'
check_equal 'doctor preserves lock and unrelated entries' "$(state_snapshot "$LOCK_ROOT")" "$LOCK_BEFORE"

run_cli_with_low_descriptors_occupied "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --platform debian
check_status 'inspect succeeds with inherited descriptors 3 through 9 occupied' 0
check_equal 'occupied descriptors preserve exact inspect output' "$STDOUT" "$PROFILE_DEBIAN_OUTPUT"
run_cli_with_low_descriptors_occupied "$PROFILE_ROOT" "$PROFILE_HOME" config doctor --platform debian
check_status 'doctor succeeds with inherited descriptors 3 through 9 occupied' 0
run_cli_with_write_only_high_descriptor "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --platform debian
check_status 'inspect succeeds with inherited write-only descriptor 254 occupied' 0
check_equal 'inspect preserves inherited write-only descriptor 254' "$DESCRIPTOR_STATUS:$DESCRIPTOR_OUTPUT" '0:descriptor-preserved'
run_cli_with_write_only_high_descriptor "$PROFILE_ROOT" "$PROFILE_HOME" config doctor --platform debian
check_status 'doctor succeeds with inherited write-only descriptor 254 occupied' 0
check_equal 'doctor preserves inherited write-only descriptor 254' "$DESCRIPTOR_STATUS:$DESCRIPTOR_OUTPUT" '0:descriptor-preserved'

fail_read_handle_open() {
    return 4
}
DOTFILES_CONFIG_TEST_READ_HANDLE_OPEN=fail_read_handle_open
OUTPUT=$(DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT=doctor dotfiles_config_state_load_internal "$PROFILE_ROOT" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_READ_HANDLE_OPEN
check_status 'doctor read-handle exhaustion is status 4' 4
check_contains 'doctor read-handle exhaustion is actionable' 'Close inherited file descriptors and rerun dotfiles config doctor.'
check_not_contains 'read-handle exhaustion is not state drift' 'changed or was replaced while being read'

replace_after_first_read() {
    local replacement="${DOTFILES_CONFIG_STATE_PATH}.replacement"
    cp "$DOTFILES_CONFIG_STATE_PATH" "$replacement"
    chmod 600 "$replacement"
    mv -f "$replacement" "$DOTFILES_CONFIG_STATE_PATH"
}
DOTFILES_CONFIG_TEST_AFTER_FIRST_READ=replace_after_first_read
OUTPUT=$(DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT=doctor dotfiles_config_state_load_internal "$PROFILE_ROOT" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_FIRST_READ
check_status 'doctor rejects observable identity drift' 3
check_contains 'doctor drift diagnostic is specific and actionable' 'Rerun dotfiles config doctor.'

change_after_first_read() {
    printf '\n' >> "$DOTFILES_CONFIG_STATE_PATH"
}
write_state "$PROFILE_ROOT" "$PROFILE_BODY"
DOTFILES_CONFIG_TEST_AFTER_FIRST_READ=change_after_first_read
OUTPUT=$(DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT=doctor dotfiles_config_state_load_internal "$PROFILE_ROOT" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_FIRST_READ
check_status 'doctor rejects observable byte drift' 3
write_state "$PROFILE_ROOT" "$PROFILE_BODY"

PRIVACY_ROOT=$(new_root privacy)
PRIVACY_HOME=$(new_home privacy)
write_state "$PRIVACY_ROOT" 'private-secret-state-contents'
run_cli "$PRIVACY_ROOT" "$PRIVACY_HOME" config doctor --platform debian
check_status 'invalid private state is unhealthy' 3
check_not_contains 'doctor diagnostic hides raw XDG root' "$PRIVACY_ROOT"
check_not_contains 'doctor diagnostic hides raw HOME' "$PRIVACY_HOME"
check_not_contains 'doctor diagnostic hides username' "$(id -un)"
check_not_contains 'doctor diagnostic hides hostname' "$(hostname)"
check_not_contains 'doctor diagnostic hides state contents' 'private-secret-state-contents'
check_not_contains 'doctor diagnostic hides device and inode identity' 'identity='
check_contains 'doctor diagnostic uses abbreviated standard origin' '$XDG_CONFIG_HOME/dotfiles/active-selection.toml'

run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect
check_status 'inspect detects the current supported platform' 0
check_contains 'detected inspect output names its platform' 'Resolved modules for '
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config doctor
check_status 'doctor detects the current supported platform' 0
check_contains 'detected doctor output names its platform' 'Composition for '

if [ ! -e "$PROBE_LOG" ]; then
    STATUS=0
    OUTPUT=
    pass 'inspect and doctor invoke no prerequisite, artifact, application, provider, installer, package-manager, network, privilege, pager, editor, render, plan, apply, cache, or managed-target helper'
else
    STATUS=97
    OUTPUT=$(< "$PROBE_LOG")
    fail 'inspect and doctor invoke no external capability helper'
fi

if [ "$failures" -ne 0 ]; then
    printf '%s config-inspection checks, %s failures\n' "$checks" "$failures" >&2
    exit 1
fi

printf '%s config-inspection checks passed\n' "$checks"
