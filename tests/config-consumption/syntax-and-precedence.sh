# Assertions for optional-base syntax and missing-state precedence.
help_output=$("$CLI" help)
for syntax in \
    'dotfiles resolve [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]' \
    'dotfiles prerequisite check [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]' \
    'dotfiles plan [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]' \
    'dotfiles apply [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian] [--yes]'; do
    OUTPUT=$help_output
    case "$help_output" in *"$syntax"*) pass "help lists optional-base syntax: ${syntax%% *} ${syntax#* }" ;; *) STATUS=1; fail "help lists optional-base syntax" ;; esac
done

missing_root="${TEST_ROOT}/roots/missing"
missing_home=$(new_home missing)
run_cli "$missing_root" "$missing_home" resolve --help
check_status 'resolve help does not require local state' 0
[ ! -e "$missing_root" ] && pass 'help creates no configuration root' || { STATUS=1; OUTPUT='configuration root was created'; fail 'help creates no configuration root'; }

for command in resolve 'prerequisite check' plan apply; do
    case "$command" in
        resolve) run_cli "$missing_root" "$missing_home" resolve --platform debian ;;
        'prerequisite check') run_cli "$missing_root" "$missing_home" prerequisite check --platform debian ;;
        plan) run_cli "$missing_root" "$missing_home" plan --platform debian ;;
        apply) run_cli "$missing_root" "$missing_home" apply --platform debian --yes ;;
    esac
    check_status "${command} without a base uses missing-state status" 3
    check_contains "${command} missing state gives config-set guidance" 'Run dotfiles config set or pass --profile or --modules.'
done
[ ! -e "$missing_root" ] && pass 'missing-state consumers create no root, directory, lock, snapshot, or temporary file' || { STATUS=1; OUTPUT='missing root was created'; fail 'missing-state consumers are strictly read-only'; }

run_cli "$missing_root" "$missing_home" resolve --add prompt.starship --platform debian
check_status '--add alone is valid syntax and reaches saved-state loading' 3
run_cli "$missing_root" "$missing_home" resolve --profile shell.minimal --profile shell.minimal --platform debian
check_status 'repeated profile is status 2 before state access' 2
run_cli "$missing_root" "$missing_home" prerequisite check --modules prompt.starship --modules prompt.starship --platform debian
check_status 'repeated modules are status 2 before state access' 2
run_cli "$missing_root" "$missing_home" plan --modules prompt.starship --add shell.zsh --add shell.zsh --platform debian
check_status 'repeated additions are status 2 before state access' 2
run_cli "$missing_root" "$missing_home" apply --modules prompt.starship --platform debian --platform debian --yes
check_status 'repeated platform is status 2 before state access' 2
run_cli "$missing_root" "$missing_home" apply --modules prompt.starship --yes --yes
check_status 'repeated apply acknowledgement is status 2' 2
run_cli "$missing_root" "$missing_home" resolve --profile --platform debian
check_status 'option-shaped selector value is status 2' 2
run_cli "$missing_root" "$missing_home" plan unexpected --platform debian
check_status 'unexpected positional input is status 2' 2
run_cli "$missing_root" "$missing_home" resolve --yes
check_status '--yes remains invalid outside apply' 2

