# Assertions for writer failure cleanup and destination drift windows.
DOTFILES_CONFIG_TEST_LOCK_MODE_FILE="${TEST_ROOT}/created-lock-mode"
CALLER_UMASK=$(umask)
umask 000
lock_failure_case "failure immediately after lock creation is cleaned" DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE hook_record_lock_mode_and_fail
umask "$CALLER_UMASK"
check_equal "lock creation ignores a permissive caller umask" "$(< "$DOTFILES_CONFIG_TEST_LOCK_MODE_FILE")" 700
lock_failure_case "identity capture failure is cleaned through exact lock authority" DOTFILES_CONFIG_TEST_LOCK_IDENTITY_CAPTURE
lock_failure_case "identity validation failure cleans the registered lock" DOTFILES_CONFIG_TEST_LOCK_IDENTITY_VALIDATION
lock_failure_case "validation failure after registration cleans the owned lock" DOTFILES_CONFIG_TEST_AFTER_LOCK
lock_failure_case "permission validation failure cleans the exact owned lock" DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE hook_make_lock_mode_unsafe

LOCK_SETUP_SIGNAL_ROOT="${TEST_ROOT}/lock-setup-signal"
write_state "$LOCK_SETUP_SIGNAL_ROOT" "${PROFILE_BODY}"$'\n'
LOCK_SETUP_SIGNAL_BEFORE=$(cksum < "$LOCK_SETUP_SIGNAL_ROOT/dotfiles/active-selection.toml")
DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE=hook_hup
run_state "$LOCK_SETUP_SIGNAL_ROOT" "" prompt.starship "" debian
check_status "HUP during lock setup returns 129" 129
check_equal "HUP during lock setup preserves prior state" "$(cksum < "$LOCK_SETUP_SIGNAL_ROOT/dotfiles/active-selection.toml")" "$LOCK_SETUP_SIGNAL_BEFORE"
assert_no_owned_debris "HUP during lock setup cleans the exact owned lock" "$LOCK_SETUP_SIGNAL_ROOT/dotfiles"
reset_hooks

LOCK_REPLACEMENT_TARGET="${TEST_ROOT}/lock-replacement-target"
mkdir "$LOCK_REPLACEMENT_TARGET"
chmod 700 "$LOCK_REPLACEMENT_TARGET"
DOTFILES_CONFIG_TEST_LOCK_REPLACEMENT_TARGET=$LOCK_REPLACEMENT_TARGET
LOCK_REPLACED_LINK_ROOT="${TEST_ROOT}/lock-replaced-link"
write_state "$LOCK_REPLACED_LINK_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE=hook_replace_lock_with_symlink
run_state "$LOCK_REPLACED_LINK_ROOT" "" prompt.starship "" debian
check_status "symlink replacement during lock setup fails safely" 4
if [ -L "$LOCK_REPLACED_LINK_ROOT/dotfiles/active-selection.lock" ]; then STATUS=0; OUTPUT=; pass "cleanup leaves a symlink replacement untouched"; else STATUS=1; OUTPUT='symlink replacement changed'; fail "cleanup leaves a symlink replacement untouched"; fi
check_equal "cleanup never follows the symlink replacement" "$(identity_of "$LOCK_REPLACEMENT_TARGET")" "$(identity_of "$(readlink "$LOCK_REPLACED_LINK_ROOT/dotfiles/active-selection.lock")")"
assert_no_private_files "symlink replacement failure leaves no private files" "$LOCK_REPLACED_LINK_ROOT/dotfiles"
reset_hooks

LOCK_REPLACED_DIRECTORY_ROOT="${TEST_ROOT}/lock-replaced-directory"
LOCK_REPLACEMENT_IDENTITY_FILE="${TEST_ROOT}/lock-replacement-identity"
DOTFILES_CONFIG_TEST_LOCK_REPLACEMENT_IDENTITY_FILE=$LOCK_REPLACEMENT_IDENTITY_FILE
write_state "$LOCK_REPLACED_DIRECTORY_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE=hook_replace_lock_with_directory
run_state "$LOCK_REPLACED_DIRECTORY_ROOT" "" prompt.starship "" debian
check_status "different-directory replacement during lock setup fails safely" 4
check_equal "cleanup preserves the different lock identity" "$(identity_of "$LOCK_REPLACED_DIRECTORY_ROOT/dotfiles/active-selection.lock")" "$(< "$LOCK_REPLACEMENT_IDENTITY_FILE")"
assert_no_private_files "different-directory replacement leaves no private files" "$LOCK_REPLACED_DIRECTORY_ROOT/dotfiles"
reset_hooks

failure_case "temporary-write failure preserves prior state" DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE
failure_case "file-flush failure preserves prior state" DOTFILES_CONFIG_TEST_FILE_FLUSH
failure_case "rename failure preserves prior state" DOTFILES_CONFIG_TEST_BEFORE_RENAME

TEMP_LINK_ROOT="${TEST_ROOT}/temp-link"
write_state "$TEMP_LINK_ROOT" "${PROFILE_BODY}"$'\n'
TEMP_LINK_BEFORE=$(cksum "$TEMP_LINK_ROOT/dotfiles/active-selection.toml")
DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE=hook_replace_temp_with_symlink
run_state "$TEMP_LINK_ROOT" "" prompt.starship "" debian
check_status "symlink replacement of the private temporary file is rejected" 3
check_equal "temporary symlink replacement preserves prior state" "$(cksum "$TEMP_LINK_ROOT/dotfiles/active-selection.toml")" "$TEMP_LINK_BEFORE"
check_equal "temporary symlink replacement never writes its target" "$(< "${TEST_ROOT}/temp-link-target")" 'external target sentinel'
if find "$TEMP_LINK_ROOT/dotfiles" -maxdepth 1 -type l -name '.active-selection.tmp.*' -print -quit | grep -q .; then STATUS=0; OUTPUT=; pass "cleanup does not remove an externally replaced temporary path"; else STATUS=1; OUTPUT='external replacement was removed'; fail "cleanup does not remove an externally replaced temporary path"; fi
reset_hooks

POST_VALIDATE_ROOT="${TEST_ROOT}/post-validation-failure"
write_state "$POST_VALIDATE_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_RENAME=hook_fail
run_state "$POST_VALIDATE_ROOT" "" prompt.starship "" debian
check_status "post-rename validation failure is uncertain" 4
check_contains "post-validation uncertainty recommends doctor" 'Run dotfiles config doctor'
assert_no_owned_debris "post-validation failure cleans owned temporary material" "$POST_VALIDATE_ROOT/dotfiles"
reset_hooks

DIRECTORY_FLUSH_ROOT="${TEST_ROOT}/directory-flush-failure"
write_state "$DIRECTORY_FLUSH_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_DIRECTORY_FLUSH=hook_fail
run_state "$DIRECTORY_FLUSH_ROOT" "" prompt.starship "" debian
check_status "directory-flush failure is uncertain" 4
check_contains "directory-flush uncertainty recommends doctor" 'Run dotfiles config doctor'
assert_no_owned_debris "directory-flush failure cleans owned temporary material" "$DIRECTORY_FLUSH_ROOT/dotfiles"
reset_hooks

DRIFT_ROOT="${TEST_ROOT}/pre-rename-drift"
write_state "$DRIFT_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE=hook_external_drift
run_state "$DRIFT_ROOT" "" prompt.starship "" debian
check_status "observed external drift before rename returns status 3" 3
check_equal "observed pre-rename drift preserves external bytes" "$(< "$DRIFT_ROOT/dotfiles/active-selection.toml")" 'external writer bytes'
assert_no_owned_debris "pre-rename drift cleans owned temporary material" "$DRIFT_ROOT/dotfiles"
reset_hooks

POST_DRIFT_ROOT="${TEST_ROOT}/post-rename-drift"
write_state "$POST_DRIFT_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_AFTER_RENAME=hook_post_rename_drift
run_state "$POST_DRIFT_ROOT" "" prompt.starship "" debian
check_status "post-rename drift returns uncertain status 4" 4
check_file_exact "post-rename drift is not rolled back" "$POST_DRIFT_ROOT/dotfiles/active-selection.toml" "$PROFILE_BODY"
check_contains "post-rename drift recommends doctor" 'Run dotfiles config doctor'
reset_hooks

FINAL_WINDOW_ROOT="${TEST_ROOT}/final-window"
write_state "$FINAL_WINDOW_ROOT" "${PROFILE_BODY}"$'\n'
FINAL_WINDOW_PRIOR_IDENTITY=$(identity_of "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml")
FINAL_WINDOW_PRIOR_CHECKSUM=$(cksum < "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml")
FINAL_WINDOW_PROPOSED_FILE="${TEST_ROOT}/final-window-proposed"
FINAL_WINDOW_CONFLICT_FILE="${TEST_ROOT}/final-window-conflict"
printf '%s\n' "$ALTERNATE_BODY" > "$FINAL_WINDOW_PROPOSED_FILE"
printf '%s\n' "$EXTERNAL_CONFLICT_BODY" > "$FINAL_WINDOW_CONFLICT_FILE"
FINAL_WINDOW_PROPOSED_CHECKSUM=$(cksum < "$FINAL_WINDOW_PROPOSED_FILE")
FINAL_WINDOW_CONFLICT_CHECKSUM=$(cksum < "$FINAL_WINDOW_CONFLICT_FILE")
run_command dotfiles_config_parse_file "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml"
check_status "final-window prior body is canonical schema 1" 0
run_command dotfiles_config_parse_file "$FINAL_WINDOW_PROPOSED_FILE"
check_status "final-window proposed body is canonical schema 1" 0
run_command dotfiles_config_parse_file "$FINAL_WINDOW_CONFLICT_FILE"
check_status "final-window external-conflict body is canonical schema 1" 0
FINAL_WINDOW_EXTERNAL_IDENTITY_FILE="${TEST_ROOT}/final-window-external-identity"
FINAL_WINDOW_EXTERNAL_CHECKSUM_FILE="${TEST_ROOT}/final-window-external-checksum"
DOTFILES_CONFIG_TEST_FINAL_WINDOW_IDENTITY_FILE=$FINAL_WINDOW_EXTERNAL_IDENTITY_FILE
DOTFILES_CONFIG_TEST_FINAL_WINDOW_CHECKSUM_FILE=$FINAL_WINDOW_EXTERNAL_CHECKSUM_FILE
DOTFILES_CONFIG_TEST_AFTER_FINAL_CHECK=hook_external_final_window
run_state "$FINAL_WINDOW_ROOT" "" prompt.starship "" debian
check_status "non-cooperating write in the final check-to-rename window cannot be serialized portably" 0
FINAL_WINDOW_EXTERNAL_IDENTITY=$(< "$FINAL_WINDOW_EXTERNAL_IDENTITY_FILE")
FINAL_WINDOW_EXTERNAL_CHECKSUM=$(< "$FINAL_WINDOW_EXTERNAL_CHECKSUM_FILE")
FINAL_WINDOW_RESULT_IDENTITY=$(identity_of "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml")
FINAL_WINDOW_RESULT_CHECKSUM=$(cksum < "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml")
check_not_equal "final-window prior and external conflict are distinct canonical states" "$FINAL_WINDOW_PRIOR_CHECKSUM" "$FINAL_WINDOW_EXTERNAL_CHECKSUM"
check_not_equal "final-window external conflict differs from the proposal" "$FINAL_WINDOW_EXTERNAL_CHECKSUM" "$FINAL_WINDOW_PROPOSED_CHECKSUM"
check_equal "final-window hook published the complete conflicting canonical document" "$FINAL_WINDOW_EXTERNAL_CHECKSUM" "$FINAL_WINDOW_CONFLICT_CHECKSUM"
check_not_equal "final-window hook replaced the prior destination object" "$FINAL_WINDOW_EXTERNAL_IDENTITY" "$FINAL_WINDOW_PRIOR_IDENTITY"
check_not_equal "ordinary rename displaced the external conflict object" "$FINAL_WINDOW_RESULT_IDENTITY" "$FINAL_WINDOW_EXTERNAL_IDENTITY"
check_file_exact "final-window replacement still publishes one complete canonical document" "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml" "$ALTERNATE_BODY"
check_equal "final-window destination checksum is exactly the proposal" "$FINAL_WINDOW_RESULT_CHECKSUM" "$FINAL_WINDOW_PROPOSED_CHECKSUM"
check_not_equal "final-window destination is not the prior document" "$FINAL_WINDOW_RESULT_CHECKSUM" "$FINAL_WINDOW_PRIOR_CHECKSUM"
check_not_equal "final-window destination is not the external conflict" "$FINAL_WINDOW_RESULT_CHECKSUM" "$FINAL_WINDOW_EXTERNAL_CHECKSUM"
run_command dotfiles_config_parse_file "$FINAL_WINDOW_ROOT/dotfiles/active-selection.toml"
check_status "final-window destination strictly parses as canonical schema 1" 0
assert_no_owned_debris "final-window replacement leaves no owned debris" "$FINAL_WINDOW_ROOT/dotfiles"
reset_hooks
