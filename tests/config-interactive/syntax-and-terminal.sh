# Assertions for command syntax, terminal requirements, and inventory.
run_command "$CLI" help
check_status "help succeeds" 0
check_contains "help lists exact interactive syntax" 'dotfiles config interactive [--platform macos|debian]'
check_contains "help lists released inspect" 'dotfiles config inspect [--profile <profile-id> | --modules <id,id>]'
check_contains "help lists released doctor" 'dotfiles config doctor [--platform macos|debian]'
check_not_contains "help still omits cache reset" 'cache reset'

for arguments in \
    '--platform' \
    '--platform --help' \
    '--platform debian --platform macos' \
    '--profile shell.minimal' \
    '--modules shell.zsh' \
    '--add prompt.starship' \
    '--yes' \
    '--destination /tmp' \
    '--unknown' \
    'positional'; do
    new_case "syntax-${checks}"
    # Intentional word splitting supplies static invalid argument fixtures.
    # shellcheck disable=SC2086
    run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive $arguments
    check_status "interactive syntax rejects ${arguments}" 2
    check_not_contains "syntax rejection prints no inventory for ${arguments}" 'Available profiles'
    check_path_absent "syntax rejection creates no configuration root for ${arguments}" "$CASE_CONFIG"
done

run_command "$CLI" config interactive --help
check_status "interactive help does not require a terminal" 0
check_contains "interactive help uses built-in usage" 'dotfiles config interactive [--platform macos|debian]'

new_case non-terminal
CHEZMOI_BEFORE=$(wc -l < "$CHEZMOI_LOG" 2>/dev/null || printf 0)
run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive --platform debian
check_status "redirected stdin is rejected" 2
check_equal "non-terminal rejection writes no stdout" "$STDOUT" ""
check_contains "non-terminal rejection is actionable" 'config interactive requires terminal stdin'
check_not_contains "non-terminal rejection prints no inventory" 'Available profiles'
check_path_absent "non-terminal rejection creates no configuration root" "$CASE_CONFIG"
check_equal "non-terminal rejection reads no catalog" "$(wc -l < "$CHEZMOI_LOG" 2>/dev/null || printf 0)" "$CHEZMOI_BEFORE"

new_case non-terminal-existing-state
write_state "$CASE_CONFIG" 'malformed current state'
NON_TERMINAL_PATH="$CASE_CONFIG/dotfiles/active-selection.toml"
NON_TERMINAL_IDENTITY=$(identity_of "$NON_TERMINAL_PATH")
NON_TERMINAL_CHECKSUM=$(cksum < "$NON_TERMINAL_PATH")
run_command env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive --platform debian
check_status "non-terminal input fails before existing-state validation" 2
check_contains "non-terminal existing-state rejection remains actionable" 'config interactive requires terminal stdin'
check_equal "non-terminal rejection preserves existing state identity" "$(identity_of "$NON_TERMINAL_PATH")" "$NON_TERMINAL_IDENTITY"
check_equal "non-terminal rejection preserves existing state bytes" "$(cksum < "$NON_TERMINAL_PATH")" "$NON_TERMINAL_CHECKSUM"
assert_no_debris "non-terminal rejection creates no lock or temporary material" "$CASE_CONFIG/dotfiles"

new_case piped-input
run_piped $'profile\nshell.minimal\n\nyes\n' env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive --platform debian
check_status "piped stdin is rejected" 2
check_path_absent "piped stdin creates no configuration root" "$CASE_CONFIG"

new_case closed-input
run_closed_stdin env XDG_CONFIG_HOME="$CASE_CONFIG" HOME="$CASE_HOME" "$CLI" config interactive --platform debian
check_status "closed stdin is rejected" 2
check_path_absent "closed stdin creates no configuration root" "$CASE_CONFIG"

new_case invalid-platform
run_tty '[]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform linux
check_status "invalid terminal platform is rejected" 3
check_not_contains "invalid platform prints no inventory" 'Available profiles'
check_path_absent "invalid platform creates no configuration root" "$CASE_CONFIG"

new_case profile-cancel
HOME_BEFORE=$(tree_snapshot "$CASE_HOME")
EVENTS=$(selection_events profile shell.minimal "" no)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
EXPECTED_PROFILE_CANCEL="${PROFILE_INVENTORY}
Base type (profile or modules):
Profile ID:
Additional module IDs (comma-separated, empty for none):
Proposed local selection:
Base: profile shell.minimal
Additional modules: none
Resolved modules for debian:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship
Save this local selection? Type yes to continue:
Cancelled. Local selection was not changed.
Managed home configuration: unchanged."
check_status "profile cancellation succeeds" 0
check_equal "profile inventory, prompts, proposal, and cancellation are exact" "$STDOUT" "$EXPECTED_PROFILE_CANCEL"
check_not_contains "profile flow omits the module-base prompt" 'Module IDs (comma-separated):'
check_equal "profile cancellation writes no stderr" "$STDERR" ""
check_path_absent "missing-state cancellation creates no configuration root" "$CASE_CONFIG"
check_equal "profile cancellation leaves managed HOME unchanged" "$(tree_snapshot "$CASE_HOME")" "$HOME_BEFORE"

new_case detected-platform
EVENTS=$(selection_events profile shell.minimal "" no)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive
check_status "interactive platform detection succeeds" 0
case "$(uname -s)" in Darwin) DETECTED_PLATFORM=macos ;; *) DETECTED_PLATFORM=debian ;; esac
check_contains "detected platform is used in inventory" "Available profiles for ${DETECTED_PLATFORM}:"
check_path_absent "detected-platform cancellation creates no state" "$CASE_CONFIG"

new_case empty-inventory
EVENTS='[{"wait":"Base type (profile or modules):\n","eof":true}]'
run_tty "$EVENTS" "${TEST_ROOT}/fixtures/empty-inventory" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "empty inventory reaches the first prompt" 2
check_contains "empty profile category prints none" $'Available profiles for debian:\n  none'
check_contains "empty module category prints none" $'Available modules for debian:\n  none'
check_not_contains "empty inventory leaks no catalog metadata" 'summary'
check_path_absent "empty inventory EOF creates no state" "$CASE_CONFIG"

