# Assertions for target scope, ordering, idempotency, and convergence.
for platform in macos debian; do
    home=$(new_home "${platform}-starship")
    printf 'unselected Zsh sentinel\n' > "$home/.zshrc"
    desired=$(render_desired "${platform}-starship" "$home" "" prompt.starship "" "$platform")
    expected_home="${TEST_ROOT}/homes/${platform}-starship-expected"
    cp -R "$home" "$expected_home"
    copy_target "$desired" "$expected_home" .config/starship.toml
    run_apply "$home" "$starship_targets" --modules prompt.starship --platform "$platform" --yes
    check_equal "${platform} Starship apply status" "$STATUS" 0
    check_contains "${platform} Starship apply success" 'Apply complete: 1 completed, 0 failed, 0 unattempted'
    check_equal "${platform} Starship invokes one target" "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
    check_equal "${platform} Starship leaves .zshrc untouched" "$(<"$home/.zshrc")" 'unselected Zsh sentinel'
    if cmp -s "$desired/.config/starship.toml" "$home/.config/starship.toml"; then pass "${platform} Starship bytes match fresh render"; else fail "${platform} Starship bytes match fresh render"; fi
    check_equal "${platform} Starship changes only its target and required parents" \
        "$(home_snapshot "$home")" "$(home_snapshot "$expected_home")"

    OUTPUT=$(HOME="$home" "${PROJECT_ROOT}/bin/dotfiles" plan --modules prompt.starship --platform "$platform" 2>&1)
    STATUS=$?
    check_equal "${platform} successful apply makes plan converged" "$OUTPUT" 'No changes.'
    before=$(line_count "$APPLY_INVOCATION_LOG")
    run_apply "$home" "$starship_targets" --modules prompt.starship --platform "$platform" --yes
    check_equal "${platform} second apply status" "$STATUS" 0
    check_equal "${platform} second apply exact no-change" "$OUTPUT" 'No changes.'
    check_equal "${platform} second apply invokes no apply" "$INVOCATIONS_AFTER" "$before"
    run_apply "$home" "$starship_targets" --modules prompt.starship --platform "$platform"
    check_equal "${platform} no-change apply without --yes status" "$STATUS" 0
    check_equal "${platform} no-change apply without --yes output" "$OUTPUT" 'No changes.'
    check_equal "${platform} no-change apply without --yes does not invoke apply" "$INVOCATIONS_AFTER" "$before"
done

home=$(new_home add-selection)
run_apply "$home" "$(printf '%s\n' '.config/starship.toml' '.zshrc')" --modules shell.zsh --add prompt.starship --platform debian --yes
check_equal '--add apply status' "$STATUS" 0
check_contains '--add applies shared resolver selection' 'Apply complete: 2 completed, 0 failed, 0 unattempted'

reset_artifact
home=$(new_home autosuggestions)
run_apply "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform macos --yes
check_equal 'autosuggestions apply status' "$STATUS" 0
check_contains 'autosuggestions applies dependency targets' 'Apply complete: 2 completed, 0 failed, 0 unattempted'
check_equal 'autosuggestions invokes two targets' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 2
recent=$(tail -n 2 "$APPLY_INVOCATION_LOG")
check_equal 'autosuggestions target order' "$recent" "$(printf 'apply\t.config/zsh/autosuggestions.zsh\napply\t.zshrc')"

for platform in macos debian; do
    reset_artifact
    home=$(new_home "${platform}-profile")
    desired=$(render_desired "${platform}-profile" "$home" shell.minimal "" "" "$platform")
    expected_home="${TEST_ROOT}/homes/${platform}-profile-expected"
    cp -R "$home" "$expected_home"
    copy_target "$desired" "$expected_home" .config/starship.toml
    copy_target "$desired" "$expected_home" .config/zsh/autosuggestions.zsh
    copy_target "$desired" "$expected_home" .zshrc
    run_apply "$home" "$profile_targets" --profile shell.minimal --platform "$platform" --yes
    check_equal "${platform} profile apply status" "$STATUS" 0
    check_contains "${platform} profile success count" 'Apply complete: 3 completed, 0 failed, 0 unattempted'
    check_equal "${platform} profile invokes three targets" "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 3
    check_equal "${platform} profile target order" "$(tail -n 3 "$APPLY_INVOCATION_LOG")" "$(printf 'apply\t.config/starship.toml\napply\t.config/zsh/autosuggestions.zsh\napply\t.zshrc')"
    check_equal "${platform} profile changes only planned targets and required parents" \
        "$(home_snapshot "$home")" "$(home_snapshot "$expected_home")"
done

reset_artifact
home=$(new_home mixed)
desired=$(render_desired mixed "$home" shell.minimal "" "" debian)
copy_target "$desired" "$home" .config/zsh/autosuggestions.zsh
printf 'outdated Zsh\n' > "$home/.zshrc"
run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
check_equal 'mixed apply status' "$STATUS" 0
check_contains 'mixed applies only two changed targets' 'Apply complete: 2 completed, 0 failed, 0 unattempted'
check_equal 'mixed invokes only changed targets' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 2
check_equal 'mixed changed target order' "$(tail -n 2 "$APPLY_INVOCATION_LOG")" "$(printf 'apply\t.config/starship.toml\napply\t.zshrc')"

reset_artifact
home=$(new_home narrower)
run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
optional_before=$(cksum "$home/.config/starship.toml" "$home/.config/zsh/autosuggestions.zsh")
run_apply "$home" "$zsh_targets" --modules shell.zsh --platform debian --yes
check_equal 'narrower Zsh apply status' "$STATUS" 0
check_contains 'narrower Zsh applies one target' 'Apply complete: 1 completed, 0 failed, 0 unattempted'
check_equal 'narrower Zsh invokes only .zshrc' "$(tail -n 1 "$APPLY_INVOCATION_LOG")" $'apply\t.zshrc'
check_equal 'narrower Zsh preserves omitted files' "$(cksum "$home/.config/starship.toml" "$home/.config/zsh/autosuggestions.zsh")" "$optional_before"
check_not_contains 'narrower Zsh output omits Starship target' 'chezmoi:target:.config/starship.toml'
check_not_contains 'narrower Zsh output omits autosuggestions target' 'chezmoi:target:.config/zsh/autosuggestions.zsh'

