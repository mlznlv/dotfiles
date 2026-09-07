# Assertions for confirmation-time recomputation and partial failures.
home=$(new_home state-drift)
export DOTFILES_PTY_CONFIRM_HOOK=$CONFIRM_HOOK
export DOTFILES_CONFIRM_HOOK_MODE=write-target
export DOTFILES_CONFIRM_HOOK_TARGET="$home/.config/starship.toml"
run_apply_tty yes "$home" "$starship_targets" --modules prompt.starship --platform debian
check_equal 'confirmation-time destination drift status' "$STATUS" 3
check_contains 'confirmation-time destination drift is actionable' 'configuration changed or became unsafe after confirmation'
check_equal 'confirmation-time destination drift invokes no apply' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
check_private_output 'confirmation-time destination drift output is private'

home=$(new_home update-state-drift)
mkdir -p "$home/.config"
printf 'first outdated state\n' > "$home/.config/starship.toml"
export DOTFILES_CONFIRM_HOOK_TARGET="$home/.config/starship.toml"
run_apply_tty yes "$home" "$starship_targets" --modules prompt.starship --platform debian
check_equal 'confirmation-time update-to-different-update drift status' "$STATUS" 3
check_contains 'confirmation-time update-to-different-update drift is actionable' \
    'configuration changed or became unsafe after confirmation'
check_equal 'confirmation-time update-to-different-update drift invokes no apply' \
    "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
check_equal 'confirmation-time update-to-different-update preserves the newer bytes' \
    "$(<"$home/.config/starship.toml")" 'changed while confirmation was pending'

home=$(new_home prerequisite-drift)
export DOTFILES_CONFIRM_HOOK_MODE=remove-prerequisite
export DOTFILES_CONFIRM_HOOK_TARGET="$PROBE_BIN/starship"
run_apply_tty yes "$home" "$starship_targets" --modules prompt.starship --platform macos
check_equal 'confirmation-time prerequisite drift status' "$STATUS" 5
check_equal 'confirmation-time prerequisite drift invokes no apply' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
chmod +x "$PROBE_BIN/starship"

reset_artifact
home=$(new_home artifact-drift)
export DOTFILES_CONFIRM_HOOK_MODE=break-artifact
export DOTFILES_CONFIRM_HOOK_TARGET="$ARTIFACT_LINK"
run_apply_tty yes "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform debian
check_equal 'confirmation-time artifact drift status' "$STATUS" 5
check_equal 'confirmation-time artifact drift invokes no apply' "$INVOCATIONS_AFTER" "$INVOCATIONS_BEFORE"
export DOTFILES_PTY_CONFIRM_HOOK=
export DOTFILES_CONFIRM_HOOK_MODE=
export DOTFILES_CONFIRM_HOOK_TARGET=

reset_artifact
: > "$PLAN_INVOCATION_LOG"
export DOTFILES_PLAN_PROBE_AFTER_STATUS_MODE=retarget-artifact
export DOTFILES_PLAN_PROBE_AFTER_STATUS_AT=2
export DOTFILES_RETARGET_LINK=$ARTIFACT_LINK
export DOTFILES_RETARGET_TARGET=$ARTIFACT_ALTERNATE
home=$(new_home immediate-artifact-drift)
run_apply "$home" "$autosuggestions_targets" --modules shell.zsh.autosuggestions --platform macos --yes
check_equal 'immediate artifact drift status' "$STATUS" 6
check_contains 'immediate artifact drift reports partial failure' 'Apply failed: 1 completed, 1 failed, 0 unattempted'
check_contains 'immediate artifact drift reports completed target' 'completed: shell.zsh.autosuggestions chezmoi:target:.config/zsh/autosuggestions.zsh'
check_contains 'immediate artifact drift reports failed Zsh target' 'failed: shell.zsh chezmoi:target:.zshrc'
check_equal 'immediate artifact drift stops before Zsh apply' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
export DOTFILES_PLAN_PROBE_AFTER_STATUS_MODE=
export DOTFILES_RETARGET_LINK=
export DOTFILES_RETARGET_TARGET=

for failed_target in .config/starship.toml .config/zsh/autosuggestions.zsh .zshrc; do
    reset_artifact
    home=$(new_home "failure-${checks}")
    export DOTFILES_APPLY_PROBE_MODE=fail-target
    export DOTFILES_APPLY_PROBE_TARGET=$failed_target
    run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
    case "$failed_target" in
        .config/starship.toml) completed=0; unattempted=2; invoked=1; failed_module=prompt.starship ;;
        .config/zsh/autosuggestions.zsh) completed=1; unattempted=1; invoked=2; failed_module=shell.zsh.autosuggestions ;;
        .zshrc) completed=2; unattempted=0; invoked=3; failed_module=shell.zsh ;;
    esac
    check_equal "failure at ${failed_target} status" "$STATUS" 6
    check_contains "failure at ${failed_target} counts" "Apply failed: ${completed} completed, 1 failed, ${unattempted} unattempted"
    check_equal "failure at ${failed_target} stops later invocation" "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" "$invoked"
    check_contains "failure at ${failed_target} names failed owner" "failed: ${failed_module} chezmoi:target:${failed_target}"
done
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=

home=$(new_home wrong-bytes)
export DOTFILES_APPLY_PROBE_MODE=wrong-bytes
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
run_apply "$home" "$starship_targets" --modules prompt.starship --platform macos --yes
check_equal 'success with wrong bytes status' "$STATUS" 6
check_contains 'success with wrong bytes is failed, not completed' 'Apply failed: 0 completed, 1 failed, 0 unattempted'
export DOTFILES_APPLY_PROBE_MODE=delegate

for verification_mode in disappear replace-symlink; do
    home=$(new_home "verification-${verification_mode}")
    export DOTFILES_APPLY_PROBE_MODE=$verification_mode
    export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
    run_apply "$home" "$starship_targets" --modules prompt.starship --platform debian --yes
    check_equal "post-target ${verification_mode} status" "$STATUS" 6
    check_contains "post-target ${verification_mode} is failed" 'Apply failed: 0 completed, 1 failed, 0 unattempted'
done
export DOTFILES_APPLY_PROBE_MODE=delegate

reset_artifact
home=$(new_home symlink-swap)
export DOTFILES_APPLY_PROBE_MODE=swap-next-symlink
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
export DOTFILES_APPLY_PROBE_NEXT_TARGET=.config/zsh/autosuggestions.zsh
run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
check_equal 'symlink swap before next target status' "$STATUS" 6
check_contains 'symlink swap reports exact partial state' 'Apply failed: 1 completed, 1 failed, 1 unattempted'
check_equal 'symlink swap stops before affected invocation' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=
export DOTFILES_APPLY_PROBE_NEXT_TARGET=

reset_artifact
home=$(new_home between-target-edit)
mkdir -p "$home/.config/zsh"
printf 'first outdated state\n' > "$home/.config/zsh/autosuggestions.zsh"
export DOTFILES_APPLY_PROBE_MODE=edit-next-target
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
export DOTFILES_APPLY_PROBE_NEXT_TARGET=.config/zsh/autosuggestions.zsh
run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
check_equal 'between-target byte edit status' "$STATUS" 6
check_contains 'between-target byte edit reports exact partial state' \
    'Apply failed: 1 completed, 1 failed, 1 unattempted'
check_equal 'between-target byte edit stops before affected invocation' \
    "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
check_equal 'between-target byte edit preserves the newer bytes' \
    "$(<"$home/.config/zsh/autosuggestions.zsh")" 'changed between target invocations'
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=
export DOTFILES_APPLY_PROBE_NEXT_TARGET=

reset_artifact
home=$(new_home directory-swap)
export DOTFILES_APPLY_PROBE_MODE=swap-next-directory
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
export DOTFILES_APPLY_PROBE_NEXT_TARGET=.config/zsh/autosuggestions.zsh
run_apply "$home" "$profile_targets" --profile shell.minimal --platform macos --yes
check_equal 'directory swap before next target status' "$STATUS" 6
check_contains 'directory swap reports exact partial state' 'Apply failed: 1 completed, 1 failed, 1 unattempted'
check_equal 'directory swap stops before affected invocation' "$((INVOCATIONS_AFTER - INVOCATIONS_BEFORE))" 1
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=
export DOTFILES_APPLY_PROBE_NEXT_TARGET=
