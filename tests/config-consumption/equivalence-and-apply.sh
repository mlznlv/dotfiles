# Assertions for saved/explicit equivalence, planning, and application.
profile_root=$(new_root profile)
profile_home=$(new_home profile)
run_cli "$profile_root" "$profile_home" config set --profile shell.minimal --platform debian
check_status 'profile state setup succeeds' 0
profile_before=$(state_snapshot "$profile_root")
run_cli "$profile_root" "$profile_home" resolve --platform debian
local_profile_output=$STDOUT
check_status 'saved profile resolves' 0
run_cli "$profile_root" "$profile_home" resolve --profile shell.minimal --platform debian
check_equal 'saved and explicit profile resolution are byte-identical' "$STDOUT" "$local_profile_output"
run_cli "$profile_root" "$profile_home" resolve --add prompt.starship --platform debian
check_equal 'curated-profile overlap remains resolver-deduplicated' "$STDOUT" "$local_profile_output"
check_equal 'profile consumption preserves state metadata and bytes' "$(state_snapshot "$profile_root")" "$profile_before"

ordered_root=$(new_root ordered)
ordered_home=$(new_home ordered)
write_state "$ordered_root" "$ORDERED_BODY"
run_cli "$ordered_root" "$ordered_home" resolve --platform macos
ordered_local=$STDOUT
check_status 'ordered saved module intent resolves on macOS' 0
run_cli "$ordered_root" "$ordered_home" resolve --modules prompt.starship,shell.zsh --add shell.zsh.autosuggestions --platform macos
check_equal 'ordered saved modules and additions match explicit intent' "$STDOUT" "$ordered_local"

additional_root=$(new_root additional)
additional_home=$(new_home additional)
write_state "$additional_root" "$ADDITIONAL_BODY"
additional_before=$(state_snapshot "$additional_root")
run_cli "$additional_root" "$additional_home" resolve --add shell.zsh.autosuggestions --platform debian
local_add_output=$STDOUT
check_status 'invocation addition appends after saved additions' 0
run_cli "$additional_root" "$additional_home" resolve --modules shell.zsh --add prompt.starship,shell.zsh.autosuggestions --platform debian
check_equal 'saved plus invocation additions match equivalent explicit intent' "$STDOUT" "$local_add_output"
check_equal 'invocation additions do not persist or change state metadata' "$(state_snapshot "$additional_root")" "$additional_before"
run_cli "$additional_root" "$additional_home" resolve --add prompt.starship --platform debian
check_status 'duplicate saved and invocation additions fail as invalid intent' 3

starship_root=$(new_root starship)
starship_home=$(new_home starship)
write_state "$starship_root" "$STARSHIP_BODY"
starship_before=$(state_snapshot "$starship_root")
run_cli "$starship_root" "$starship_home" prerequisite check --platform debian
local_prerequisite=$OUTPUT
local_prerequisite_status=$STATUS
run_cli "$starship_root" "$starship_home" prerequisite check --modules prompt.starship --platform debian
check_equal 'saved and explicit prerequisite statuses match' "$local_prerequisite_status" "$STATUS"
check_equal 'saved and explicit prerequisite output is byte-identical' "$OUTPUT" "$local_prerequisite"

chmod -x "$PROBE_BIN/starship"
run_cli "$starship_root" "$starship_home" prerequisite check --platform debian
local_missing_prerequisite=$OUTPUT
local_missing_prerequisite_status=$STATUS
run_cli "$starship_root" "$starship_home" prerequisite check --modules prompt.starship --platform debian
check_equal 'saved and explicit missing-prerequisite statuses match' "$local_missing_prerequisite_status" "$STATUS"
check_equal 'saved and explicit missing-prerequisite output is byte-identical' "$OUTPUT" "$local_missing_prerequisite"

missing_plan_local_home=$(new_home plan-missing-local)
missing_plan_explicit_home=$(new_home plan-missing-explicit)
run_cli "$starship_root" "$missing_plan_local_home" plan --platform debian
local_missing_plan=$OUTPUT
local_missing_plan_status=$STATUS
run_cli "$starship_root" "$missing_plan_explicit_home" plan --modules prompt.starship --platform debian
check_equal 'saved and explicit missing-prerequisite plan statuses match' "$local_missing_plan_status" "$STATUS"
check_equal 'saved and explicit missing-prerequisite plan output is byte-identical' "$OUTPUT" "$local_missing_plan"
chmod +x "$PROBE_BIN/starship"

plan_local_home=$(new_home plan-local)
plan_explicit_home=$(new_home plan-explicit)
run_cli "$starship_root" "$plan_local_home" plan --platform debian
local_plan=$OUTPUT
local_plan_status=$STATUS
run_cli "$starship_root" "$plan_explicit_home" plan --modules prompt.starship --platform debian
check_equal 'saved and explicit plan statuses match' "$local_plan_status" "$STATUS"
check_equal 'saved and explicit plan output is byte-identical' "$OUTPUT" "$local_plan"

apply_local_home=$(new_home apply-local)
apply_explicit_home=$(new_home apply-explicit)
run_cli "$starship_root" "$apply_local_home" apply --platform debian --yes
local_apply=$OUTPUT
local_apply_status=$STATUS
check_status 'saved-selection apply succeeds' 0
run_cli "$starship_root" "$apply_explicit_home" apply --modules prompt.starship --platform debian --yes
check_equal 'saved and explicit apply statuses match' "$local_apply_status" "$STATUS"
check_equal 'saved and explicit apply output is byte-identical' "$OUTPUT" "$local_apply"
check_equal 'saved and explicit apply produce the same managed-home tree' "$(home_snapshot "$apply_local_home")" "$(home_snapshot "$apply_explicit_home")"
check_equal 'successful saved apply does not change selection state' "$(state_snapshot "$starship_root")" "$starship_before"
run_cli "$starship_root" "$apply_local_home" apply --platform debian
check_equal 'saved no-change apply is exact' "$STDOUT" 'No changes.'
local_no_change=$OUTPUT
local_no_change_status=$STATUS
run_cli "$starship_root" "$apply_explicit_home" apply --modules prompt.starship --platform debian
check_equal 'saved and explicit no-change apply statuses match' "$local_no_change_status" "$STATUS"
check_equal 'saved and explicit no-change apply output is byte-identical' "$OUTPUT" "$local_no_change"

partial_home=$(new_home apply-partial-failure)
export DOTFILES_REAL_CHEZMOI=$REAL_CHEZMOI
export DOTFILES_APPLY_CHEZMOI_BIN="${PROJECT_ROOT}/tests/helpers/chezmoi-apply-probe.sh"
export DOTFILES_EXPECTED_SOURCE_HOME="${PROJECT_ROOT}/home"
export DOTFILES_EXPECTED_APPLY_TARGETS=.config/starship.toml
export DOTFILES_ALLOWED_TEST_ROOT=$TEST_ROOT
export DOTFILES_APPLY_PRIVATE_PATH_LOG="${TEST_ROOT}/partial-private-paths.log"
export DOTFILES_APPLY_PRIVATE_MODE_LOG="${TEST_ROOT}/partial-private-modes.log"
export DOTFILES_APPLY_INVOCATION_LOG="${TEST_ROOT}/partial-invocations.log"
export DOTFILES_APPLY_PROBE_MODE=fail-target
export DOTFILES_APPLY_PROBE_TARGET=.config/starship.toml
run_cli "$starship_root" "$partial_home" apply --platform debian --yes
check_status 'saved-selection partial apply failure keeps status 6' 6
check_contains 'saved-selection partial apply failure reports exact outcome' 'Apply failed: 0 completed, 1 failed, 0 unattempted'
[ ! -e "$partial_home/.config/starship.toml" ] && pass 'saved-selection partial apply failure verifies no completed target' || { STATUS=1; OUTPUT='failed target exists'; fail 'saved-selection partial apply failure verifies no completed target'; }
check_equal 'saved-selection partial apply failure leaves selection unchanged' "$(state_snapshot "$starship_root")" "$starship_before"
unset DOTFILES_REAL_CHEZMOI DOTFILES_APPLY_CHEZMOI_BIN DOTFILES_EXPECTED_SOURCE_HOME
unset DOTFILES_EXPECTED_APPLY_TARGETS DOTFILES_ALLOWED_TEST_ROOT
unset DOTFILES_APPLY_PRIVATE_PATH_LOG DOTFILES_APPLY_PRIVATE_MODE_LOG
unset DOTFILES_APPLY_INVOCATION_LOG DOTFILES_APPLY_PROBE_MODE DOTFILES_APPLY_PROBE_TARGET

cancel_home=$(new_home apply-cancel)
cancel_before=$(home_snapshot "$cancel_home")
run_tty no "$starship_root" "$cancel_home" apply --platform debian
check_status 'saved apply cancellation succeeds' 0
check_contains 'saved apply cancellation is explicit' 'Cancelled. No changes were applied.'
check_equal 'saved apply cancellation leaves managed home unchanged' "$(home_snapshot "$cancel_home")" "$cancel_before"
check_equal 'saved apply cancellation leaves selection unchanged' "$(state_snapshot "$starship_root")" "$starship_before"

export DOTFILES_PTY_CONFIRM_HOOK=$CONFIRM_HOOK
for drift_mode in delete-selection corrupt-selection change-selection replace-identical-selection symlink-selection; do
    drift_root=$(new_root "drift-${drift_mode}")
    drift_home=$(new_home "drift-${drift_mode}")
    write_state "$drift_root" "$STARSHIP_BODY"
    export DOTFILES_CONFIRM_HOOK_MODE=$drift_mode
    export DOTFILES_CONFIRM_HOOK_TARGET="${drift_root}/dotfiles/active-selection.toml"
    run_tty yes "$drift_root" "$drift_home" apply --platform debian
    check_status "${drift_mode} fails before managed-home mutation" 3
    check_contains "${drift_mode} requests apply rerun" 'rerun dotfiles apply'
    [ ! -e "$drift_home/.config/starship.toml" ] && pass "${drift_mode} invokes no managed-target mutation" || { STATUS=1; OUTPUT='managed target exists'; fail "${drift_mode} invokes no managed-target mutation"; }
done

equivalent_drift_root=$(new_root drift-equivalent-selection)
equivalent_drift_home=$(new_home drift-equivalent-selection)
write_state "$equivalent_drift_root" "$PROFILE_BODY"
export DOTFILES_CONFIRM_HOOK_MODE=change-equivalent-selection
export DOTFILES_CONFIRM_HOOK_TARGET="${equivalent_drift_root}/dotfiles/active-selection.toml"
run_tty yes "$equivalent_drift_root" "$equivalent_drift_home" apply --platform debian
check_status 'equivalent resolved intent replacement fails before managed-home mutation' 3
check_contains 'equivalent resolved intent replacement requests apply rerun' 'rerun dotfiles apply'
[ ! -e "$equivalent_drift_home/.zshrc" ] && pass 'equivalent resolved intent replacement invokes no managed-target mutation' || { STATUS=1; OUTPUT='managed target exists'; fail 'equivalent resolved intent replacement invokes no managed-target mutation'; }
unset DOTFILES_PTY_CONFIRM_HOOK DOTFILES_CONFIRM_HOOK_MODE DOTFILES_CONFIRM_HOOK_TARGET
