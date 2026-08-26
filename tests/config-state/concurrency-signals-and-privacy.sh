# Assertions for signals, cooperating writers, privacy, and final cleanup.
SIGNAL_HUP_ROOT="${TEST_ROOT}/signal-hup"
write_state "$SIGNAL_HUP_ROOT" "${PROFILE_BODY}"$'\n'
HUP_BEFORE=$(cksum "$SIGNAL_HUP_ROOT/dotfiles/active-selection.toml")
DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE=hook_hup
run_state "$SIGNAL_HUP_ROOT" "" prompt.starship "" debian
check_status "HUP before rename returns 129" 129
check_equal "HUP before rename preserves prior bytes" "$(cksum "$SIGNAL_HUP_ROOT/dotfiles/active-selection.toml")" "$HUP_BEFORE"
assert_no_owned_debris "HUP cleans owned temporary material" "$SIGNAL_HUP_ROOT/dotfiles"
reset_hooks

SIGNAL_INT_ROOT="${TEST_ROOT}/signal-int"
write_state "$SIGNAL_INT_ROOT" "${PROFILE_BODY}"$'\n'
INT_BEFORE=$(cksum "$SIGNAL_INT_ROOT/dotfiles/active-selection.toml")
DOTFILES_CONFIG_TEST_AFTER_TEMP_WRITE=hook_int
run_state "$SIGNAL_INT_ROOT" "" prompt.starship "" debian
check_status "INT before rename returns 130" 130
check_equal "INT before rename preserves prior bytes" "$(cksum "$SIGNAL_INT_ROOT/dotfiles/active-selection.toml")" "$INT_BEFORE"
assert_no_owned_debris "INT cleans owned temporary material" "$SIGNAL_INT_ROOT/dotfiles"
reset_hooks

SIGNAL_TERM_ROOT="${TEST_ROOT}/signal-term-critical"
write_state "$SIGNAL_TERM_ROOT" "${PROFILE_BODY}"$'\n'
DOTFILES_CONFIG_TEST_BEFORE_RENAME=hook_term
run_state "$SIGNAL_TERM_ROOT" "" prompt.starship "" debian
check_status "TERM across the critical region returns 143 after commit handling" 143
check_file_exact "critical TERM leaves one complete committed document" "$SIGNAL_TERM_ROOT/dotfiles/active-selection.toml" "$ALTERNATE_BODY"
assert_no_owned_debris "critical TERM cleans owned temporary material" "$SIGNAL_TERM_ROOT/dotfiles"
reset_hooks

DOTFILES_CONFIG_TEST_RELEASE_FILE="${TEST_ROOT}/release-writer"
CONCURRENT_ROOT="${TEST_ROOT}/concurrent"
DOTFILES_CONFIG_TEST_AFTER_LOCK=hook_hold_lock
dotfiles_config_state_set_internal "$CONCURRENT_ROOT" shell.minimal "" "" debian > "${TEST_ROOT}/writer-one.out" 2>&1 &
WRITER_ONE_PID=$!
for attempt in {1..500}; do
    [ -d "$CONCURRENT_ROOT/dotfiles/active-selection.lock" ] && break
    sleep 0.01
done
run_state "$CONCURRENT_ROOT" "" prompt.starship "" debian
SECOND_STATUS=$STATUS
SECOND_OUTPUT=$OUTPUT
touch "$DOTFILES_CONFIG_TEST_RELEASE_FILE"
wait "$WRITER_ONE_PID"
FIRST_STATUS=$?
STATUS=$SECOND_STATUS
OUTPUT=$SECOND_OUTPUT
check_equal "a second cooperating writer fails immediately" "$SECOND_STATUS" 3
check_equal "the lock-owning writer completes" "$FIRST_STATUS" 0
check_file_exact "cooperating writers neither merge nor overwrite selections" "$CONCURRENT_ROOT/dotfiles/active-selection.toml" "$PROFILE_BODY"
assert_no_owned_debris "cooperating writer success cleans its lock" "$CONCURRENT_ROOT/dotfiles"
reset_hooks

run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" resolve --modules prompt.starship --platform debian
check_equal "explicit resolve ignores saved selection" "$STDOUT" 'prompt.starship'

PRIVACY_ROOT="${TEST_ROOT}/privacy-root"
write_state "$PRIVACY_ROOT" 'private-state-contents
'
run_state "$PRIVACY_ROOT" shell.minimal "" "" debian
check_status "invalid private state fails" 3
check_not_contains "state diagnostics hide raw configuration root" "$PRIVACY_ROOT"
check_not_contains "state diagnostics hide username" "$(id -un)"
check_not_contains "state diagnostics hide hostname" "$(hostname)"
check_not_contains "state diagnostics hide state contents" 'private-state-contents'
check_contains "state diagnostics use abbreviated origin token" '$XDG_CONFIG_HOME/dotfiles/active-selection.toml'

UNRELATED_ROOT="${TEST_ROOT}/unrelated"
mkdir "$UNRELATED_ROOT"
printf 'unrelated sentinel\n' > "$UNRELATED_ROOT/sentinel"
UNRELATED_BEFORE=$(cksum "$UNRELATED_ROOT/sentinel")
run_state "$UNRELATED_ROOT" shell.minimal "" "" debian
check_status "isolated local save succeeds beside an unrelated file" 0
check_equal "local save leaves unrelated files unchanged" "$(cksum "$UNRELATED_ROOT/sentinel")" "$UNRELATED_BEFORE"
assert_no_owned_debris "successful save leaves no temporary material" "$UNRELATED_ROOT/dotfiles"

if grep -R -E 'schema[[:space:]]*=[[:space:]]*[23]|schema (2|3)' \
    "$PROJECT_ROOT/.chezmoidata" "$PROJECT_ROOT/lib" >/dev/null 2>&1; then
    STATUS=1
    OUTPUT='schema 2 or 3 reference found in active implementation'
    fail "active catalog and state implementation remain schema 1"
else
    STATUS=0
    OUTPUT=
    pass "active catalog and state implementation remain schema 1"
fi
