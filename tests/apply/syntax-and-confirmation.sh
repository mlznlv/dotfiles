# Assertions for apply syntax, confirmation, cancellation, and preflight safety.
help_output=$("${PROJECT_ROOT}/bin/dotfiles" help)
case "$help_output" in
    *'dotfiles apply [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian] [--yes]'*) pass 'help lists exact apply syntax' ;;
    *) STATUS=1; OUTPUT=$help_output; fail 'help lists exact apply syntax' ;;
esac

for arguments in \
    '--profile shell.minimal --modules shell.zsh --yes' \
    '--modules shell.zsh --modules shell.zsh --yes' \
    '--modules shell.zsh --add prompt.starship --add prompt.starship --yes' \
    '--modules shell.zsh --platform debian --platform debian --yes' \
    '--modules shell.zsh --yes --yes' \
    '--modules shell.zsh -y' \
    '--modules shell.zsh --unknown' \
    '--modules'; do
    home=$(new_home "usage-${checks}")
    # Intentional word splitting supplies static invalid argument fixtures.
    # shellcheck disable=SC2086
    run_apply "$home" "$zsh_targets" $arguments
    check_equal "usage rejection status: ${arguments}" "$STATUS" 2
    check_zero_mutation "usage rejection does not mutate: ${arguments}"
done

home=$(new_home plan-rejects-yes)
OUTPUT=$(HOME="$home" "${PROJECT_ROOT}/bin/dotfiles" plan --modules shell.zsh --platform debian --yes 2>&1)
STATUS=$?
check_equal 'plan rejects apply-only --yes' "$STATUS" 2

home=$(new_home noninteractive)
plan=$(expected_step debian create prompt.starship home/dot_config/starship.toml .config/starship.toml)
run_apply "$home" "$starship_targets" --modules prompt.starship --platform debian
check_equal 'non-interactive apply without --yes status' "$STATUS" 2
check_contains 'non-interactive apply prints complete plan' "$plan"
check_contains 'non-interactive apply prints software disclosure' 'Software installation: none'
check_contains 'non-interactive apply is actionable' 'non-interactive apply requires --yes'
check_zero_mutation 'non-interactive apply without --yes does not mutate'
check_private_output 'non-interactive apply output is private'

home=$(new_home unsafe-selected-target)
ln -s /dev/null "$home/.zshrc"
run_apply "$home" "$zsh_targets" --modules shell.zsh --platform debian --yes
check_equal 'unsafe selected target apply status' "$STATUS" 3
check_zero_mutation 'unsafe selected target fails before mutation'

for answer in Yes ' yes' 'yes ' no '' EOF; do
    answer_name=${answer:-empty}
    home=$(new_home "cancel-${checks}")
    run_apply_tty "$answer" "$home" "$starship_targets" --modules prompt.starship --platform macos
    check_equal "interactive ${answer_name} cancellation status" "$STATUS" 0
    check_contains "interactive ${answer_name} prints cancellation" 'Cancelled. No changes were applied.'
    check_zero_mutation "interactive ${answer_name} cancellation does not mutate"
    check_private_output "interactive ${answer_name} cancellation output is private"
done

home=$(new_home interactive-yes)
plan=$(expected_step debian create shell.zsh home/dot_zshrc.tmpl .zshrc)
expected=$(printf '%s\n\nSoftware installation: none\n\nApply this configuration? Type yes to continue:\nApply complete: 1 completed, 0 failed, 0 unattempted' "$plan")
run_apply_tty yes "$home" "$zsh_targets" --modules shell.zsh --platform debian
check_equal 'interactive exact yes status' "$STATUS" 0
check_equal 'interactive exact yes output' "$OUTPUT" "$expected"
check_equal 'interactive exact yes invokes one apply' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
check_private_output 'interactive exact yes output is private'
