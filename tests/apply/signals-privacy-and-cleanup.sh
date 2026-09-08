# Assertions for signals, private output/modes, cleanup, and non-invocation.
home=$(new_home signal-before-confirmation)
export DOTFILES_PTY_CONFIRM_HOOK=$CONFIRM_HOOK
export DOTFILES_CONFIRM_HOOK_MODE=term
run_apply_tty yes "$home" "$starship_targets" --modules prompt.starship --platform macos
check_equal 'signal before confirmation status' "$STATUS" 143
check_zero_mutation 'signal before confirmation does not mutate'
export DOTFILES_PTY_CONFIRM_HOOK=
export DOTFILES_CONFIRM_HOOK_MODE=

for signal_target in .config/starship.toml .config/zsh/autosuggestions.zsh; do
    reset_artifact
    home=$(new_home "signal-${checks}")
    export DOTFILES_APPLY_PROBE_MODE=term-target
    export DOTFILES_APPLY_PROBE_TARGET=$signal_target
    run_apply "$home" "$profile_targets" --profile shell.minimal --platform debian --yes
    case "$signal_target" in
        .config/starship.toml) signal_completed=0; signal_unattempted=2 ;;
        *) signal_completed=1; signal_unattempted=1 ;;
    esac
    check_equal "signal during ${signal_target} status" "$STATUS" 143
    check_contains "signal during ${signal_target} partial report" "Apply failed: ${signal_completed} completed, 1 failed, ${signal_unattempted} unattempted"
done
export DOTFILES_APPLY_PROBE_MODE=delegate
export DOTFILES_APPLY_PROBE_TARGET=

home=$(new_home inspect-private)
export DOTFILES_PTY_CONFIRM_HOOK=$CONFIRM_HOOK
export DOTFILES_CONFIRM_HOOK_MODE=inspect-private
run_apply_tty no "$home" "$starship_targets" --modules prompt.starship --platform debian
if [ -s "$CONFIRM_PRIVATE_MODE_LOG" ] && ! grep -Ev '^(directory 700|file 600)$' "$CONFIRM_PRIVATE_MODE_LOG" | grep -q .; then
    pass 'displayed apply authority uses only mode 700 directories and mode 600 files'
else
    STATUS=1; OUTPUT='unexpected displayed authority mode'; fail 'displayed apply authority uses only mode 700 directories and mode 600 files'
fi
export DOTFILES_PTY_CONFIRM_HOOK=
export DOTFILES_CONFIRM_HOOK_MODE=

if [ -f "$APPLY_PRIVATE_MODE_LOG" ] && ! grep -Ev '^600 700 700 700 600 600 600 600 700$' "$APPLY_PRIVATE_MODE_LOG" | grep -q .; then
    pass 'apply context, cache, records, and captures use restrictive modes'
else
    STATUS=1; OUTPUT='unexpected apply private mode'; fail 'apply context, cache, records, and captures use restrictive modes'
fi

cleanup_ok=1
cleanup_remaining=
for path_log in "$PRIVATE_PATH_LOG" "$APPLY_PRIVATE_PATH_LOG" "$CONTEXT_PATH_LOG"; do
    [ -f "$path_log" ] || continue
    while IFS= read -r private_path; do
        [ -n "$private_path" ] || continue
        if [ -e "$private_path" ]; then
            cleanup_ok=0
            cleanup_remaining="${cleanup_remaining}${cleanup_remaining:+ }${private_path}"
        fi
    done < "$path_log"
done
if find "$TMPDIR" -maxdepth 1 -type d \( -name 'dotfiles-apply.*' -o -name 'dotfiles-plan.*' -o -name 'dotfiles-render.*' \) -print -quit | grep -q .; then
    cleanup_ok=0
    cleanup_remaining="${cleanup_remaining}${cleanup_remaining:+ }$(find "$TMPDIR" -maxdepth 1 -type d \( -name 'dotfiles-apply.*' -o -name 'dotfiles-plan.*' -o -name 'dotfiles-render.*' \) -print)"
fi
if [ "$cleanup_ok" -eq 1 ]; then pass 'all apply, plan, render, cache, state, and capture paths are removed'; else STATUS=1; OUTPUT="private paths remain: ${cleanup_remaining}"; fail 'all apply, plan, render, cache, state, and capture paths are removed'; fi

if [ ! -e "$PROBE_LOG" ]; then
    pass 'apply invokes no provider, prerequisite, artifact, pager, editor, external diff, secret, network, or privilege helper'
else
    STATUS=97
    OUTPUT=$(<"$PROBE_LOG")
    fail 'apply invokes no provider, prerequisite, artifact, pager, editor, external diff, secret, network, or privilege helper'
fi
