# Assertions for confirmation, persisted state, cancellation, and convergence.
for answer in Yes YES y 'yes ' ' yes' $'yes\t' 'yes please' '' __EOF__; do
    new_case "cancel-${checks}"
    EVENTS=$(selection_events profile shell.minimal "" "$answer")
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "non-exact confirmation cancels: ${answer:-empty}" 0
    check_contains "non-exact confirmation reports cancellation: ${answer:-empty}" 'Cancelled. Local selection was not changed.'
    check_not_contains "non-exact confirmation never reports saved: ${answer:-empty}" 'Local selection saved.'
    check_path_absent "non-exact confirmation creates no root: ${answer:-empty}" "$CASE_CONFIG"
done

new_case save-profile
HOME_BEFORE=$(tree_snapshot "$CASE_HOME")
EVENTS=$(selection_events profile shell.minimal "" yes)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "exact yes saves a profile selection" 0
check_contains "profile save reports success" 'Local selection saved.'
check_equal "profile save writes no stderr" "$STDERR" ""
check_equal "profile save emits canonical schema-1 bytes" "$(< "$CASE_CONFIG/dotfiles/active-selection.toml")" "$PROFILE_BODY"
check_equal "interactive directory mode is 0700" "$(mode_of "$CASE_CONFIG/dotfiles")" 700
check_equal "interactive file mode is 0600" "$(mode_of "$CASE_CONFIG/dotfiles/active-selection.toml")" 600
check_equal "interactive profile save leaves managed HOME unchanged" "$(tree_snapshot "$CASE_HOME")" "$HOME_BEFORE"
PROFILE_INTERACTIVE_FILE="$CASE_CONFIG/dotfiles/active-selection.toml"

new_case set-profile-reference
run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config set --profile shell.minimal --platform debian
check_status "config set profile reference succeeds" 0
if cmp -s "$PROFILE_INTERACTIVE_FILE" "$CASE_CONFIG/dotfiles/active-selection.toml"; then
    pass "interactive and config set profile bytes are identical"
else
    STATUS=1
    OUTPUT='profile state bytes differ'
    fail "interactive and config set profile bytes are identical"
fi

new_case save-modules
EVENTS=$(selection_events modules prompt.starship,shell.zsh shell.zsh.autosuggestions yes)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform macos
check_status "exact yes saves ordered modules and additions" 0
check_contains "macOS inventory preserves deterministic catalog order" "$MACOS_INVENTORY"
check_contains "module flow uses only the module-base prompt" 'Module IDs (comma-separated):'
check_not_contains "module flow omits the profile prompt" 'Profile ID:'
check_contains "module proposal preserves base order" 'Base: modules prompt.starship,shell.zsh'
check_contains "module proposal preserves addition order" 'Additional modules: shell.zsh.autosuggestions'
check_equal "module flow emits canonical schema-1 bytes" "$(< "$CASE_CONFIG/dotfiles/active-selection.toml")" "$MODULE_BODY"
MODULE_INTERACTIVE_FILE="$CASE_CONFIG/dotfiles/active-selection.toml"

new_case set-module-reference
run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config set --modules prompt.starship,shell.zsh --add shell.zsh.autosuggestions --platform macos
check_status "config set module reference succeeds" 0
if cmp -s "$MODULE_INTERACTIVE_FILE" "$CASE_CONFIG/dotfiles/active-selection.toml"; then
    pass "interactive and config set module bytes are identical"
else
    STATUS=1
    OUTPUT='module state bytes differ'
    fail "interactive and config set module bytes are identical"
fi

new_case unchanged
write_state "$CASE_CONFIG" "$PROFILE_BODY"
UNCHANGED_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
UNCHANGED_IDENTITY=$(identity_of "$UNCHANGED_PATH")
UNCHANGED_MODE=$(mode_of "$UNCHANGED_PATH")
UNCHANGED_CHECKSUM=$(cksum < "$UNCHANGED_PATH")
EVENTS=$(selection_events profile shell.minimal "" __NONE__)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "identical interactive state succeeds without confirmation" 0
check_contains "identical state reports unchanged" 'Local selection unchanged.'
check_not_contains "identical state never asks for confirmation" 'Save this local selection?'
check_not_contains "identical state never reports saved" 'Local selection saved.'
check_equal "no-change preserves state identity" "$(identity_of "$UNCHANGED_PATH")" "$UNCHANGED_IDENTITY"
check_equal "no-change preserves state mode" "$(mode_of "$UNCHANGED_PATH")" "$UNCHANGED_MODE"
check_equal "no-change preserves state bytes" "$(cksum < "$UNCHANGED_PATH")" "$UNCHANGED_CHECKSUM"
assert_no_debris "no-change preflight cleans its transient authority" "$CASE_CONFIG/dotfiles"

new_case existing-cancel
write_state "$CASE_CONFIG" "$STARSHIP_BODY"
EXISTING_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
EXISTING_IDENTITY=$(identity_of "$EXISTING_PATH")
EXISTING_MODE=$(mode_of "$EXISTING_PATH")
EXISTING_CHECKSUM=$(cksum < "$EXISTING_PATH")
EVENTS=$(selection_events profile shell.minimal "" no)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "cancellation with existing state succeeds" 0
check_equal "existing cancellation preserves identity" "$(identity_of "$EXISTING_PATH")" "$EXISTING_IDENTITY"
check_equal "existing cancellation preserves mode" "$(mode_of "$EXISTING_PATH")" "$EXISTING_MODE"
check_equal "existing cancellation preserves bytes" "$(cksum < "$EXISTING_PATH")" "$EXISTING_CHECKSUM"
assert_no_debris "existing cancellation cleans preflight material" "$CASE_CONFIG/dotfiles"

new_case invalid-current
write_state "$CASE_CONFIG" 'schema = 1

[selection]
profile = "shell.minimal"'
INVALID_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
INVALID_IDENTITY=$(identity_of "$INVALID_PATH")
INVALID_CHECKSUM=$(cksum < "$INVALID_PATH")
EVENTS=$(selection_events profile shell.minimal "" __NONE__)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "invalid current state fails before confirmation" 3
check_not_contains "invalid current state never asks for confirmation" 'Save this local selection?'
check_equal "invalid current state preserves identity" "$(identity_of "$INVALID_PATH")" "$INVALID_IDENTITY"
check_equal "invalid current state preserves bytes" "$(cksum < "$INVALID_PATH")" "$INVALID_CHECKSUM"
assert_no_debris "invalid-current preflight cleans transient material" "$CASE_CONFIG/dotfiles"

new_case active-lock
write_state "$CASE_CONFIG" "$STARSHIP_BODY"
mkdir "$CASE_CONFIG/dotfiles/active-selection.lock"
chmod 700 "$CASE_CONFIG/dotfiles/active-selection.lock"
LOCK_IDENTITY=$(identity_of "$CASE_CONFIG/dotfiles/active-selection.lock")
EVENTS=$(selection_events profile shell.minimal "" __NONE__)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "active writer lock fails before confirmation" 3
check_not_contains "active writer lock never asks for confirmation" 'Save this local selection?'
check_equal "pre-existing writer lock is preserved" "$(identity_of "$CASE_CONFIG/dotfiles/active-selection.lock")" "$LOCK_IDENTITY"

new_case confirmation-convergence
write_state "$CASE_CONFIG" "$STARSHIP_BODY"
STATE_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
BODY_FILE="$CASE_ROOT/profile-body"
IDENTITY_FILE="$CASE_ROOT/external-identity"
printf '%s\n' "$PROFILE_BODY" > "$BODY_FILE"
export DOTFILES_PTY_EVENT_HOOK=$STATE_HOOK
export DOTFILES_PTY_STATE_PATH=$STATE_PATH
export DOTFILES_PTY_STATE_BODY_FILE=$BODY_FILE
export DOTFILES_PTY_IDENTITY_FILE=$IDENTITY_FILE
EVENTS=$(selection_events profile shell.minimal "" yes hook)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
unset DOTFILES_PTY_EVENT_HOOK DOTFILES_PTY_STATE_PATH DOTFILES_PTY_STATE_BODY_FILE DOTFILES_PTY_IDENTITY_FILE
check_status "confirmation-time convergence succeeds" 0
check_contains "fresh writer reports confirmation-time convergence unchanged" 'Local selection unchanged.'
check_not_contains "confirmation-time convergence is not rewritten" 'Local selection saved.'
check_equal "fresh writer preserves the converged external object" "$(identity_of "$STATE_PATH")" "$(< "$IDENTITY_FILE")"
check_equal "confirmation-time convergence leaves exact proposal bytes" "$(< "$STATE_PATH")" "$PROFILE_BODY"
assert_no_debris "confirmation-time convergence leaves no owned debris" "$CASE_CONFIG/dotfiles"

