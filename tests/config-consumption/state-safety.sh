# Assertions for explicit bypass, canonical state safety, and root precedence.
invalid_root=$(new_root invalid-explicit-bypass)
invalid_home=$(new_home invalid-explicit-bypass)
write_state "$invalid_root" 'not canonical private state'
invalid_before=$(state_snapshot "$invalid_root")
run_cli "$invalid_root" "$invalid_home" resolve --modules prompt.starship --platform debian
check_status 'explicit resolve ignores invalid local state' 0
run_cli "$invalid_root" "$invalid_home" prerequisite check --modules prompt.starship --platform debian
check_status 'explicit prerequisite check ignores invalid local state' 0
run_cli "$invalid_root" "$invalid_home" plan --modules prompt.starship --platform debian
check_status 'explicit plan ignores invalid local state' 0
run_cli "$invalid_root" "$invalid_home" apply --modules prompt.starship --platform debian --yes
check_status 'explicit apply ignores invalid local state' 0
check_equal 'explicit consumers never repair or rewrite invalid local state' "$(state_snapshot "$invalid_root")" "$invalid_before"

copy_root="${TEST_ROOT}/without-config-state"
mkdir "$copy_root"
cp -R "${PROJECT_ROOT}/bin" "${PROJECT_ROOT}/lib" "${PROJECT_ROOT}/home" "${PROJECT_ROOT}/.chezmoidata" "$copy_root/"
rm -f -- "$copy_root/lib/config-state.sh"
copy_home=$(new_home no-state-component)
for command in resolve prerequisite plan apply; do
    case "$command" in
        resolve) OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" resolve --modules prompt.starship --platform debian 2>&1); STATUS=$? ;;
        prerequisite) OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" prerequisite check --modules prompt.starship --platform debian 2>&1); STATUS=$? ;;
        plan) OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" plan --modules prompt.starship --platform debian 2>&1); STATUS=$? ;;
        apply) OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" apply --modules prompt.starship --platform debian --yes 2>&1); STATUS=$? ;;
    esac
    check_status "explicit ${command} does not require the config-state component" 0
done
OUTPUT=$(HOME="$copy_home" "$copy_root/bin/dotfiles" resolve --platform debian 2>&1)
STATUS=$?
check_status 'saved selection reports missing state component as status 4' 4

safety_home=$(new_home safety)
for fixture in noncanonical schema unknown-field both-bases empty-modules unknown-module; do
    safety_root=$(new_root "unsafe-${fixture}")
    case "$fixture" in
        noncanonical) body=$'# comment\nschema = 1\n\n[selection]\nmodules = ["prompt.starship"]\nadditional_modules = []' ;;
        schema) body=$'schema = 2\n\n[selection]\nmodules = ["prompt.starship"]\nadditional_modules = []' ;;
        unknown-field) body=$'schema = 1\n\n[selection]\nmodules = ["prompt.starship"]\nadditional_modules = []\nunexpected = "value"' ;;
        both-bases) body=$'schema = 1\n\n[selection]\nprofile = "shell.minimal"\nmodules = ["prompt.starship"]\nadditional_modules = []' ;;
        empty-modules) body=$'schema = 1\n\n[selection]\nmodules = []\nadditional_modules = []' ;;
        unknown-module) body=$'schema = 1\n\n[selection]\nmodules = ["shell.unknown"]\nadditional_modules = []' ;;
    esac
    write_state "$safety_root" "$body"
    fixture_before=$(state_snapshot "$safety_root")
    run_cli "$safety_root" "$safety_home" resolve --platform debian
    check_status "${fixture} local state fails closed" 3
    check_equal "${fixture} local state is not repaired" "$(state_snapshot "$safety_root")" "$fixture_before"
done

mode_root=$(new_root unsafe-mode)
write_state "$mode_root" "$STARSHIP_BODY"
chmod 644 "$mode_root/dotfiles/active-selection.toml"
run_cli "$mode_root" "$safety_home" resolve --platform debian
check_status 'unsafe state mode fails closed' 3

directory_mode_root=$(new_root unsafe-directory-mode)
write_state "$directory_mode_root" "$STARSHIP_BODY"
chmod 755 "$directory_mode_root/dotfiles"
run_cli "$directory_mode_root" "$safety_home" resolve --platform debian
check_status 'unsafe dedicated-directory mode fails closed' 3

symlink_root=$(new_root symlink-state)
mkdir "$symlink_root/dotfiles"
chmod 700 "$symlink_root/dotfiles"
ln -s /dev/null "$symlink_root/dotfiles/active-selection.toml"
run_cli "$symlink_root" "$safety_home" resolve --platform debian
check_status 'state symlink fails closed without being opened' 3

hardlink_root=$(new_root hardlink-state)
write_state "$hardlink_root" "$STARSHIP_BODY"
ln "$hardlink_root/dotfiles/active-selection.toml" "$hardlink_root/dotfiles/selection-alias"
run_cli "$hardlink_root" "$safety_home" resolve --platform debian
check_status 'hard-linked state fails closed' 3

type_root=$(new_root wrong-state-type)
mkdir "$type_root/dotfiles"
chmod 700 "$type_root/dotfiles"
mkdir "$type_root/dotfiles/active-selection.toml"
run_cli "$type_root" "$safety_home" resolve --platform debian
check_status 'wrong state type fails closed' 3

inside_project_root=$PROJECT_ROOT
run_cli "$inside_project_root" "$safety_home" resolve --platform debian
check_status 'configuration root inside the repository fails closed' 3

real_symlink_root=$(new_root symlink-root-target)
write_state "$real_symlink_root" "$STARSHIP_BODY"
symlink_config_root="${TEST_ROOT}/roots/symlink-root"
ln -s "$real_symlink_root" "$symlink_config_root"
run_cli "$symlink_config_root" "$safety_home" resolve --platform debian
check_status 'symlinked standard configuration root fails closed' 3

precedence_home=$(new_home precedence)
mkdir -p "$precedence_home/.config"
chmod 700 "$precedence_home/.config"
write_state "$precedence_home/.config" "$PROFILE_BODY"
precedence_xdg=$(new_root precedence-xdg)
write_state "$precedence_xdg" "$STARSHIP_BODY"
run_cli "$precedence_xdg" "$precedence_home" resolve --platform debian
check_equal 'non-empty XDG root takes precedence over HOME fallback' "$STDOUT" 'prompt.starship'
run_cli_without_xdg "$precedence_home" resolve --platform debian
check_equal 'unset XDG uses HOME fallback selection' "$STDOUT" $'shell.zsh\nshell.zsh.autosuggestions\nprompt.starship'
