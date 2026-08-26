# Assertions for descriptor pressure, verified-read drift, and privacy.
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

DOTFILES_CONFIG_TEST_READ_HANDLE_OPEN=fail_read_handle_open
OUTPUT=$(DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT=doctor dotfiles_config_state_load_internal "$PROFILE_ROOT" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_READ_HANDLE_OPEN
check_status 'doctor read-handle exhaustion is status 4' 4
check_contains 'doctor read-handle exhaustion is actionable' 'Close inherited file descriptors and rerun dotfiles config doctor.'
check_not_contains 'read-handle exhaustion is not state drift' 'changed or was replaced while being read'

DOTFILES_CONFIG_TEST_AFTER_FIRST_READ=replace_after_first_read
OUTPUT=$(DOTFILES_CONFIG_DIAGNOSTIC_CONTEXT=doctor dotfiles_config_state_load_internal "$PROFILE_ROOT" debian 2>&1)
STATUS=$?
unset DOTFILES_CONFIG_TEST_AFTER_FIRST_READ
check_status 'doctor rejects observable identity drift' 3
check_contains 'doctor drift diagnostic is specific and actionable' 'Rerun dotfiles config doctor.'

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
