# Assertions for literal input, composition, and incomplete input.
for invalid_type in '' Profile MODULES 1 prof modules1 ' profile'; do
    new_case "invalid-base-${checks}"
    EVENTS=$(base_event "$invalid_type")
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "literal base type is rejected: ${invalid_type:-empty}" 3
    check_not_contains "invalid base type shows no profile prompt: ${invalid_type:-empty}" 'Profile ID:'
    check_not_contains "invalid base type shows no module prompt: ${invalid_type:-empty}" 'Module IDs (comma-separated):'
    check_not_contains "invalid base type shows no additions prompt: ${invalid_type:-empty}" 'Additional module IDs'
    check_path_absent "invalid base type creates no state: ${invalid_type:-empty}" "$CASE_CONFIG"
done

for invalid_profile in '' Shell.Minimal 1 shell '"shell.minimal"' 'shell.minimal ' $'shell.minimal\t' shell.unknown; do
    new_case "invalid-profile-${checks}"
    EVENTS=$(selection_events profile "$invalid_profile" "" __NONE__)
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "literal profile input is rejected: ${invalid_profile:-empty}" 3
    check_contains "invalid profile still requests additions: ${invalid_profile:-empty}" 'Additional module IDs (comma-separated, empty for none):'
    check_not_contains "invalid profile prints no proposal: ${invalid_profile:-empty}" 'Proposed local selection:'
    check_path_absent "invalid profile creates no state: ${invalid_profile:-empty}" "$CASE_CONFIG"
done

for invalid_modules in '' 1 shell 'Shell.Zsh' '"shell.zsh"' 'shell.zsh ' 'shell.zsh,prompt.starship,' 'shell.zsh,,prompt.starship' 'shell.zsh, prompt.starship' 'shell.zsh,shell.zsh' 'shell.zsh\prompt.starship' 'shell.zsh;prompt.starship' $'shell.zsh\t' shell.unknown; do
    new_case "invalid-modules-${checks}"
    EVENTS=$(selection_events modules "$invalid_modules" "" __NONE__)
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "literal module input is rejected: ${invalid_modules:-empty}" 3
    check_contains "invalid modules still request additions: ${invalid_modules:-empty}" 'Additional module IDs (comma-separated, empty for none):'
    check_not_contains "invalid modules print no proposal: ${invalid_modules:-empty}" 'Proposed local selection:'
    check_path_absent "invalid modules create no state: ${invalid_modules:-empty}" "$CASE_CONFIG"
done

for invalid_additions in 'prompt.starship,prompt.starship' 'shell.zsh' ' prompt.starship' 'prompt.starship ' 'prompt.starship,' 'prompt.starship,,shell.zsh' 'PROMPT.starship' '"prompt.starship"' 'prompt.starship;false' $'prompt.starship\t' prompt.unknown; do
    new_case "invalid-additions-${checks}"
    EVENTS=$(selection_events modules shell.zsh "$invalid_additions" __NONE__)
    run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
    check_status "literal additions are rejected: ${invalid_additions}" 3
    check_not_contains "invalid additions print no proposal: ${invalid_additions}" 'Proposed local selection:'
    check_path_absent "invalid additions create no state: ${invalid_additions}" "$CASE_CONFIG"
done

new_case dependency-expansion
EVENTS=$(selection_events modules shell.zsh.autosuggestions "" no)
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "dependency-expanded proposal succeeds" 0
check_contains "dependency appears before the selected dependent" $'Resolved modules for debian:\n  shell.zsh\n  shell.zsh.autosuggestions'
check_path_absent "dependency proposal cancellation creates no state" "$CASE_CONFIG"

for fixture_case in exclusive conflict unsupported cycle collision; do
    new_case "composition-${fixture_case}"
    case "$fixture_case" in
        exclusive)
            SOURCE="${TEST_ROOT}/fixtures/valid"
            PLATFORM=macos
            BASE=terminal.ghostty,terminal.wezterm
            ;;
        conflict)
            SOURCE="${TEST_ROOT}/fixtures/valid"
            PLATFORM=macos
            BASE=shell.zsh,terminal.wezterm
            ;;
        unsupported)
            SOURCE="${TEST_ROOT}/fixtures/valid"
            PLATFORM=debian
            BASE=terminal.ghostty
            ;;
        cycle)
            SOURCE="${TEST_ROOT}/fixtures/cycle"
            PLATFORM=debian
            BASE=shell.alpha
            ;;
        collision)
            SOURCE="${TEST_ROOT}/fixtures/source-collision"
            PLATFORM=debian
            BASE=shell.alpha,shell.beta
            ;;
    esac
    if [ "$fixture_case" = cycle ]; then
        EVENTS='[]'
    else
        EVENTS=$(selection_events modules "$BASE" "" __NONE__)
    fi
    run_tty "$EVENTS" "$SOURCE" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform "$PLATFORM"
    check_status "${fixture_case} composition fails before confirmation" 3
    check_not_contains "${fixture_case} composition prints no proposal" 'Proposed local selection:'
    check_path_absent "${fixture_case} composition creates no state" "$CASE_CONFIG"
    if [ "$fixture_case" = cycle ]; then
        check_not_contains "invalid catalog prints no partial inventory" 'Available profiles'
    fi
done

new_case incomplete-base-type
run_tty '[{"wait":"Base type (profile or modules):\n","eof":true}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "EOF at base type is incomplete" 2
check_contains "base-type EOF is diagnosed" 'incomplete interactive local selection'
check_path_absent "base-type EOF creates no state" "$CASE_CONFIG"

new_case incomplete-profile
run_tty '[{"wait":"Base type (profile or modules):\n","send":"profile"},{"wait":"Profile ID:\n","eof":true}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "EOF at profile is incomplete" 2
check_path_absent "profile EOF creates no state" "$CASE_CONFIG"

new_case incomplete-modules
run_tty '[{"wait":"Base type (profile or modules):\n","send":"modules"},{"wait":"Module IDs (comma-separated):\n","eof":true}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "EOF at module base is incomplete" 2
check_path_absent "module EOF creates no state" "$CASE_CONFIG"

new_case incomplete-additions
run_tty '[{"wait":"Base type (profile or modules):\n","send":"profile"},{"wait":"Profile ID:\n","send":"shell.minimal"},{"wait":"Additional module IDs (comma-separated, empty for none):\n","eof":true}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "EOF at additions is incomplete" 2
check_path_absent "additions EOF creates no state" "$CASE_CONFIG"

