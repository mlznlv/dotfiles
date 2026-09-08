# Assertions for syntax, missing state, output, and healthy local state.
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
