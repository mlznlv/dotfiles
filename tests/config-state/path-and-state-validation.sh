# Assertions for current-state, path, type, mode, and lock validation.
invalid_state_case "malformed current TOML is preserved" 'not toml
'
invalid_state_case "unknown current key is preserved" 'schema = 1

[selection]
profile = "shell.minimal"
unknown = []
additional_modules = []
'
invalid_state_case "unknown current table is preserved" 'schema = 1

[other]
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "wrong current type is preserved" 'schema = 1

[selection]
profile = ["shell.minimal"]
additional_modules = []
'
invalid_state_case "unknown current schema is preserved" 'schema = 2

[selection]
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "duplicate current TOML key is preserved" 'schema = 1

[selection]
profile = "shell.minimal"
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "current comments are non-canonical and preserved" 'schema = 1

[selection]
profile = "shell.minimal"
additional_modules = [] # comment
'
invalid_state_case "alternative current ordering is preserved" 'schema = 1

[selection]
additional_modules = []
profile = "shell.minimal"
'
invalid_state_case "alternative current spacing is preserved" 'schema=1

[selection]
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "extra current blank line is preserved" 'schema = 1


[selection]
profile = "shell.minimal"
additional_modules = []
'
invalid_state_case "missing current final newline is preserved" "$PROFILE_BODY"
invalid_state_case "extra current final newline is preserved" "${PROFILE_BODY}

"
invalid_state_case "both current bases are preserved" 'schema = 1

[selection]
profile = "shell.minimal"
modules = ["shell.zsh"]
additional_modules = []
'
invalid_state_case "neither current base is preserved" 'schema = 1

[selection]
additional_modules = []
'
invalid_state_case "empty current module base is preserved" 'schema = 1

[selection]
modules = []
additional_modules = []
'
invalid_state_case "duplicate current explicit intent is preserved" 'schema = 1

[selection]
modules = ["shell.zsh", "shell.zsh"]
additional_modules = []
'
invalid_state_case "cross-list duplicate current intent is preserved" 'schema = 1

[selection]
modules = ["shell.zsh"]
additional_modules = ["shell.zsh"]
'
invalid_state_case "catalog-invalid canonical current state is preserved" 'schema = 1

[selection]
modules = ["shell.unknown"]
additional_modules = []
'

NEW_ROOT="${TEST_ROOT}/one-level-root"
umask 000
run_state "$NEW_ROOT" shell.minimal "" "" debian
umask 022
check_status "private seam creates a one-level root" 0
check_equal "created root ignores permissive umask" "$(mode_of "$NEW_ROOT")" 700
check_equal "created dedicated directory ignores permissive umask" "$(mode_of "$NEW_ROOT/dotfiles")" 700
check_equal "created state ignores permissive umask" "$(mode_of "$NEW_ROOT/dotfiles/active-selection.toml")" 600

DEEP_ROOT="${TEST_ROOT}/missing-parent/missing-root"
run_state "$DEEP_ROOT" shell.minimal "" "" debian
check_status "writer does not recursively invent a root chain" 3
if [ ! -e "${TEST_ROOT}/missing-parent" ]; then STATUS=0; OUTPUT=; pass "failed deep root creates no parent"; else STATUS=1; OUTPUT='parent was created'; fail "failed deep root creates no parent"; fi

REPO_STATE_ROOT="${PROJECT_ROOT}/.forbidden-config-state-test"
run_state "$REPO_STATE_ROOT" shell.minimal "" "" debian
check_status "configuration root inside repository is rejected" 3
if [ ! -e "$REPO_STATE_ROOT" ]; then STATUS=0; OUTPUT=; pass "repository rejection creates no state"; else STATUS=1; OUTPUT='repository path was created'; fail "repository rejection creates no state"; fi

HOME_FALLBACK="${TEST_ROOT}/fallback-home"
mkdir "$HOME_FALLBACK"
run_command env -u XDG_CONFIG_HOME HOME="$HOME_FALLBACK" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform debian
check_status "unset XDG uses HOME fallback" 0
if [ -f "$HOME_FALLBACK/.config/dotfiles/active-selection.toml" ]; then STATUS=0; OUTPUT=; pass "unset XDG writes the literal HOME fallback"; else STATUS=1; OUTPUT='fallback missing'; fail "unset XDG writes the literal HOME fallback"; fi

EMPTY_XDG_HOME="${TEST_ROOT}/empty-xdg-home"
mkdir "$EMPTY_XDG_HOME"
run_command env XDG_CONFIG_HOME= HOME="$EMPTY_XDG_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform macos
check_status "empty XDG uses HOME fallback" 0
if [ -f "$EMPTY_XDG_HOME/.config/dotfiles/active-selection.toml" ]; then STATUS=0; OUTPUT=; pass "empty XDG writes the literal HOME fallback"; else STATUS=1; OUTPUT='fallback missing'; fail "empty XDG writes the literal HOME fallback"; fi

PRECEDENCE_HOME="${TEST_ROOT}/precedence-home"
mkdir "$PRECEDENCE_HOME"
run_command env XDG_CONFIG_HOME=relative HOME="$PRECEDENCE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform debian
check_status "invalid non-empty XDG fails closed" 3
PRECEDENCE_OUTPUT=$OUTPUT
if [ ! -e "$PRECEDENCE_HOME/.config" ]; then STATUS=0; OUTPUT=; pass "invalid XDG never falls back to HOME"; else STATUS=1; OUTPUT='HOME fallback was used'; fail "invalid XDG never falls back to HOME"; fi
OUTPUT=$PRECEDENCE_OUTPUT
check_not_contains "invalid XDG diagnostic hides raw root" 'relative'
check_contains "invalid XDG diagnostic uses origin token" '$XDG_CONFIG_HOME'

for malformed_root in \
    "${TEST_ROOT}//ambiguous" \
    "${TEST_ROOT}/./dot" \
    "${TEST_ROOT}/../escape" \
    "${TEST_ROOT}/with~tilde" \
    "${TEST_ROOT}/with\$variable" \
    "${TEST_ROOT}/with*glob" \
    "${TEST_ROOT}/with;syntax"; do
    run_state "$malformed_root" shell.minimal "" "" debian
    if [ "$STATUS" -eq 3 ] && [[ $OUTPUT != *"$malformed_root"* ]]; then
        pass "malformed literal root fails privately"
    else
        fail "malformed literal root fails privately"
    fi
done

SYMLINK_TARGET="${TEST_ROOT}/symlink-target"
mkdir "$SYMLINK_TARGET"
ln -s "$SYMLINK_TARGET" "${TEST_ROOT}/root-link"
run_state "${TEST_ROOT}/root-link" shell.minimal "" "" debian
check_status "symlink configuration root is rejected" 3

mkdir "${TEST_ROOT}/component-real"
ln -s "${TEST_ROOT}/component-real" "${TEST_ROOT}/component-link"
mkdir "${TEST_ROOT}/component-real/root"
run_state "${TEST_ROOT}/component-link/root" shell.minimal "" "" debian
check_status "symlink path component is rejected" 3

DEDICATED_LINK_ROOT="${TEST_ROOT}/dedicated-link"
mkdir "$DEDICATED_LINK_ROOT" "${TEST_ROOT}/dedicated-target"
ln -s "${TEST_ROOT}/dedicated-target" "$DEDICATED_LINK_ROOT/dotfiles"
run_state "$DEDICATED_LINK_ROOT" shell.minimal "" "" debian
check_status "symlink dedicated directory is rejected" 3

STATE_LINK_ROOT="${TEST_ROOT}/state-link"
mkdir -p "$STATE_LINK_ROOT/dotfiles"
chmod 700 "$STATE_LINK_ROOT/dotfiles"
printf '%s\n' "$PROFILE_BODY" > "${TEST_ROOT}/state-link-target"
chmod 600 "${TEST_ROOT}/state-link-target"
ln -s "${TEST_ROOT}/state-link-target" "$STATE_LINK_ROOT/dotfiles/active-selection.toml"
run_state "$STATE_LINK_ROOT" shell.minimal "" "" debian
check_status "symlink state file is rejected" 3

MODE_ROOT="${TEST_ROOT}/unsafe-directory-mode"
mkdir -p "$MODE_ROOT/dotfiles"
chmod 755 "$MODE_ROOT/dotfiles"
run_state "$MODE_ROOT" shell.minimal "" "" debian
check_status "group-readable dedicated directory is rejected" 3
check_equal "unsafe dedicated mode is not repaired" "$(mode_of "$MODE_ROOT/dotfiles")" 755

FILE_MODE_ROOT="${TEST_ROOT}/unsafe-file-mode"
write_state "$FILE_MODE_ROOT" "${PROFILE_BODY}"$'\n'
chmod 644 "$FILE_MODE_ROOT/dotfiles/active-selection.toml"
run_state "$FILE_MODE_ROOT" shell.minimal "" "" debian
check_status "group-readable state file is rejected" 3
check_equal "unsafe state mode is not repaired" "$(mode_of "$FILE_MODE_ROOT/dotfiles/active-selection.toml")" 644

WRONG_DIRECTORY_ROOT="${TEST_ROOT}/wrong-directory-type"
mkdir "$WRONG_DIRECTORY_ROOT"
printf 'not a directory\n' > "$WRONG_DIRECTORY_ROOT/dotfiles"
run_state "$WRONG_DIRECTORY_ROOT" shell.minimal "" "" debian
check_status "wrong dedicated-directory type is rejected" 3

WRONG_STATE_ROOT="${TEST_ROOT}/wrong-state-type"
mkdir -p "$WRONG_STATE_ROOT/dotfiles/active-selection.toml"
chmod 700 "$WRONG_STATE_ROOT/dotfiles"
run_state "$WRONG_STATE_ROOT" shell.minimal "" "" debian
check_status "wrong state-file type is rejected" 3

UNWRITABLE_ROOT="${TEST_ROOT}/unwritable"
mkdir -p "$UNWRITABLE_ROOT/dotfiles"
chmod 700 "$UNWRITABLE_ROOT/dotfiles"
chmod 500 "$UNWRITABLE_ROOT"
run_state "$UNWRITABLE_ROOT" shell.minimal "" "" debian
check_status "unwritable mutation root is rejected" 3
chmod 700 "$UNWRITABLE_ROOT"

SYSTEM_ROOT=
for candidate in /private/tmp /var/tmp /tmp; do
    if [ -d "$candidate" ] && [ ! -L "$candidate" ] && [ "$(dotfiles_config_stat_owner "$candidate")" != "$(id -u)" ]; then
        SYSTEM_ROOT=$candidate
        break
    fi
done
if [ -n "$SYSTEM_ROOT" ]; then
    run_state "$SYSTEM_ROOT" shell.minimal "" "" debian
    check_status "ownership mismatch is rejected" 3
else
    STATUS=0
    OUTPUT=
    pass "ownership mismatch fixture unavailable for this user"
fi

LOCK_ROOT="${TEST_ROOT}/active-lock"
mkdir -p "$LOCK_ROOT/dotfiles/active-selection.lock"
chmod 700 "$LOCK_ROOT/dotfiles" "$LOCK_ROOT/dotfiles/active-selection.lock"
printf 'pre-existing lock sentinel\n' > "$LOCK_ROOT/dotfiles/active-selection.lock/sentinel"
LOCK_IDENTITY_BEFORE=$(identity_of "$LOCK_ROOT/dotfiles/active-selection.lock")
LOCK_MODE_BEFORE=$(mode_of "$LOCK_ROOT/dotfiles/active-selection.lock")
LOCK_SENTINEL_BEFORE=$(cksum < "$LOCK_ROOT/dotfiles/active-selection.lock/sentinel")
run_state "$LOCK_ROOT" shell.minimal "" "" debian
check_status "active or stale writer lock is refused" 3
check_equal "pre-existing lock identity is unchanged" "$(identity_of "$LOCK_ROOT/dotfiles/active-selection.lock")" "$LOCK_IDENTITY_BEFORE"
check_equal "pre-existing lock mode is unchanged" "$(mode_of "$LOCK_ROOT/dotfiles/active-selection.lock")" "$LOCK_MODE_BEFORE"
check_equal "pre-existing lock contents are unchanged" "$(cksum < "$LOCK_ROOT/dotfiles/active-selection.lock/sentinel")" "$LOCK_SENTINEL_BEFORE"

LOCK_FILE_ROOT="${TEST_ROOT}/lock-file"
mkdir -p "$LOCK_FILE_ROOT/dotfiles"
chmod 700 "$LOCK_FILE_ROOT/dotfiles"
printf 'unowned lock object\n' > "$LOCK_FILE_ROOT/dotfiles/active-selection.lock"
chmod 600 "$LOCK_FILE_ROOT/dotfiles/active-selection.lock"
LOCK_FILE_IDENTITY=$(identity_of "$LOCK_FILE_ROOT/dotfiles/active-selection.lock")
LOCK_FILE_CHECKSUM=$(cksum < "$LOCK_FILE_ROOT/dotfiles/active-selection.lock")
run_state "$LOCK_FILE_ROOT" shell.minimal "" "" debian
check_status "pre-existing non-directory lock is refused" 3
check_equal "pre-existing non-directory lock identity is unchanged" "$(identity_of "$LOCK_FILE_ROOT/dotfiles/active-selection.lock")" "$LOCK_FILE_IDENTITY"
check_equal "pre-existing non-directory lock bytes are unchanged" "$(cksum < "$LOCK_FILE_ROOT/dotfiles/active-selection.lock")" "$LOCK_FILE_CHECKSUM"

LOCK_LINK_ROOT="${TEST_ROOT}/lock-link"
mkdir -p "$LOCK_LINK_ROOT/dotfiles" "${TEST_ROOT}/lock-link-target"
chmod 700 "$LOCK_LINK_ROOT/dotfiles" "${TEST_ROOT}/lock-link-target"
ln -s "${TEST_ROOT}/lock-link-target" "$LOCK_LINK_ROOT/dotfiles/active-selection.lock"
run_state "$LOCK_LINK_ROOT" shell.minimal "" "" debian
check_status "symlink writer lock is refused" 3
if [ -L "$LOCK_LINK_ROOT/dotfiles/active-selection.lock" ]; then STATUS=0; OUTPUT=; pass "writer never follows or removes a symlink lock"; else STATUS=1; OUTPUT='lock link changed'; fail "writer never follows or removes a symlink lock"; fi
