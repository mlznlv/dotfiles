# Assertions for state path, type, mode, and adjacent-lock safety.
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
