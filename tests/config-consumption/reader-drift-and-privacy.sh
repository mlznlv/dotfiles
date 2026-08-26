# Assertions for verified reads, descriptor pressure, drift, and privacy.
reader_root=$(new_root reader-drift-bytes)
write_state "$reader_root" "$STARSHIP_BODY"
DRIFT_STATE="$reader_root/dotfiles/active-selection.toml"
DOTFILES_CONFIG_TEST_AFTER_FIRST_READ=replace_reader_bytes
OUTPUT=$(dotfiles_config_state_load_internal "$reader_root" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_FIRST_READ
check_status 'observable byte drift during read fails closed' 3
check_contains 'byte drift diagnostic is actionable' 'changed or was replaced while being read'

reader_size_root=$(new_root reader-drift-size)
write_state "$reader_size_root" "$STARSHIP_BODY"
DRIFT_STATE="$reader_size_root/dotfiles/active-selection.toml"
DOTFILES_CONFIG_TEST_AFTER_FIRST_READ=append_reader_bytes
OUTPUT=$(dotfiles_config_state_load_internal "$reader_size_root" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_FIRST_READ
check_status 'observable same-identity size drift during read fails closed' 3
check_contains 'same-identity size drift is not capability exhaustion' 'changed or was replaced while being read'

reader_identity_root=$(new_root reader-drift-identity)
write_state "$reader_identity_root" "$STARSHIP_BODY"
DRIFT_STATE="$reader_identity_root/dotfiles/active-selection.toml"
DOTFILES_CONFIG_TEST_AFTER_READ_VALIDATION=replace_reader_identity
OUTPUT=$(dotfiles_config_state_load_internal "$reader_identity_root" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_READ_VALIDATION
check_status 'observable identity drift during read fails closed' 3

stable_root=$(new_root stable-read)
stable_home=$(new_home stable-read)
write_state "$stable_root" "$STARSHIP_BODY"
stable_before=$(state_snapshot "$stable_root")
run_cli "$stable_root" "$stable_home" resolve --platform macos
check_status 'strict read succeeds on macOS input' 0
check_equal 'strict read creates no lock, snapshot, temporary file, or metadata change' "$(state_snapshot "$stable_root")" "$stable_before"
run_cli_with_low_descriptors_occupied "$stable_root" "$stable_home" resolve --platform macos
check_status 'strict read succeeds with inherited descriptors 3 through 9 occupied' 0
check_equal 'occupied low descriptors preserve exact resolution output' "$STDOUT" 'prompt.starship'

DOTFILES_CONFIG_TEST_READ_HANDLE_OPEN=fail_read_handle_open
OUTPUT=$(dotfiles_config_state_load_internal "$stable_root" macos 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_READ_HANDLE_OPEN
check_status 'read-handle allocation exhaustion is status 4' 4
check_contains 'read-handle allocation exhaustion has capability guidance' 'local selection read handle is unavailable'
check_not_contains 'read-handle allocation exhaustion is not reported as state drift' 'changed or was replaced while being read'

privacy_root=$(new_root privacy)
write_state "$privacy_root" 'private-state-contents-must-not-appear'
run_cli "$privacy_root" "$safety_home" resolve --platform debian
check_status 'invalid private state uses status 3' 3
check_not_contains 'diagnostic hides raw configuration root' "$privacy_root"
check_not_contains 'diagnostic hides raw HOME' "$safety_home"
check_not_contains 'diagnostic hides username' "$(id -un)"
check_not_contains 'diagnostic hides hostname' "$(hostname)"
check_not_contains 'diagnostic hides state contents' 'private-state-contents-must-not-appear'
check_contains 'diagnostic uses abbreviated standard root' '$XDG_CONFIG_HOME/dotfiles/active-selection.toml'

if [ ! -e "$PROBE_LOG" ]; then
    STATUS=0
    OUTPUT=
    pass 'consumption invokes no provider, installer, prerequisite, artifact, network, privilege, pager, or editor helper'
else
    STATUS=97
    OUTPUT=$(< "$PROBE_LOG")
    fail 'consumption invokes no external capability helper'
fi
