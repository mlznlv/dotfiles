# Assertions for CLI syntax, canonical persistence, and catalog validation.
LOCK_HANDLE_PROBE="${TEST_ROOT}/lock-handle-probe"
mkdir "$LOCK_HANDLE_PROBE"
DOTFILES_CONFIG_LOCK_PATH=$LOCK_HANDLE_PROBE
DOTFILES_CONFIG_DIRECTORY=$TEST_ROOT
DOTFILES_CONFIG_LOCK_DEVICE=$(dotfiles_config_stat_device "$DOTFILES_CONFIG_DIRECTORY")
DOTFILES_CONFIG_LOCK_FD=
DOTFILES_CONFIG_LOCK_FD_OPEN=0
if dotfiles_config_open_lock_handle; then
    check_equal "lock-handle identity includes the created directory device and inode" \
        "$(dotfiles_config_lock_handle_identity)" \
        "$(dotfiles_config_stat_identity "$LOCK_HANDLE_PROBE")"
    LOCK_HANDLE_OTHER_PROBE="${TEST_ROOT}/lock-handle-other-probe"
    mkdir "$LOCK_HANDLE_OTHER_PROBE"
    DOTFILES_CONFIG_LOCK_PATH=$LOCK_HANDLE_OTHER_PROBE
    if ! dotfiles_config_lock_handle_matches_path; then
        pass "lock-handle identity rejects a different device or inode"
    else
        STATUS=1
        OUTPUT='a different directory matched the retained descriptor'
        fail "lock-handle identity rejects a different device or inode"
    fi
    dotfiles_config_close_lock_handle
else
    STATUS=1
    OUTPUT='no private lock descriptor available'
    fail "lock-handle identity includes the created directory device and inode"
    fail "lock-handle identity rejects a different device or inode"
fi

run_command "$CLI" help
check_status "help succeeds" 0
check_contains "help lists config set" 'dotfiles config set (--profile <profile-id> | --modules <id,id>)'
check_contains "help lists interactive config" 'dotfiles config interactive [--platform macos|debian]'
check_contains "help lists inspect" 'dotfiles config inspect [--profile <profile-id> | --modules <id,id>]'
check_contains "help lists doctor" 'dotfiles config doctor [--platform macos|debian]'
check_not_contains "help omits cache reset" 'cache reset'

run_command "$CLI" config
check_status "config requires a subcommand" 2
run_command "$CLI" config unknown
check_status "unknown config subcommand is usage error" 2
run_command "$CLI" config set
check_status "config set requires a base" 2
run_command "$CLI" config set --profile shell.minimal --modules shell.zsh
check_status "both bases are a usage error" 2
run_command "$CLI" config set --modules ''
check_status "empty module base is a usage error" 2
run_command "$CLI" config set --profile
check_status "missing profile value is a usage error" 2
run_command "$CLI" config set --profile --platform debian
check_status "option-shaped profile value is missing" 2
run_command "$CLI" config set --profile shell.minimal --profile shell.minimal
check_status "repeated profile is a usage error" 2
run_command "$CLI" config set --modules shell.zsh --modules prompt.starship
check_status "repeated modules are a usage error" 2
run_command "$CLI" config set --profile shell.minimal --add prompt.starship --add shell.zsh
check_status "repeated additions are a usage error" 2
run_command "$CLI" config set --profile shell.minimal --platform debian --platform macos
check_status "repeated platform is a usage error" 2
run_command "$CLI" config set --profile shell.minimal --unknown
check_status "unknown config set flag is a usage error" 2
run_command "$CLI" config set --profile shell.minimal positional
check_status "positional config set argument is a usage error" 2
run_command "$CLI" config set --profile shell.minimal --yes
check_status "config set exposes no approval flag" 2
run_command "$CLI" config set --help
check_status "config set help succeeds without a base" 0

PROFILE_ROOT="${TEST_ROOT}/profile-state"
PROFILE_HOME="${TEST_ROOT}/profile-home"
mkdir "$PROFILE_HOME"
printf 'private-home-sentinel\n' > "$PROFILE_HOME/sentinel"
HOME_BEFORE=$(tree_snapshot "$PROFILE_HOME")
expected_profile_output='Proposed local selection:
Base: profile shell.minimal
Additional modules: none
Resolved modules for debian:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship
Local selection saved.
Managed home configuration: unchanged.'
run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform debian
check_status "profile selection saves on Debian" 0
check_equal "saved profile summary is exact" "$STDOUT" "$expected_profile_output"
check_equal "saved profile writes no stderr" "$STDERR" ""
check_file_exact "profile state uses exact canonical bytes" "$PROFILE_ROOT/dotfiles/active-selection.toml" "$PROFILE_BODY"
check_equal "dedicated directory mode is 0700" "$(mode_of "$PROFILE_ROOT/dotfiles")" 700
check_equal "state file mode is 0600" "$(mode_of "$PROFILE_ROOT/dotfiles/active-selection.toml")" 600
check_equal "managed HOME is unchanged" "$(tree_snapshot "$PROFILE_HOME")" "$HOME_BEFORE"

PROFILE_IDENTITY=$(identity_of "$PROFILE_ROOT/dotfiles/active-selection.toml")
PROFILE_MODE=$(mode_of "$PROFILE_ROOT/dotfiles/active-selection.toml")
PROFILE_CKSUM=$(cksum "$PROFILE_ROOT/dotfiles/active-selection.toml")
run_command env XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set --profile shell.minimal --platform debian
check_status "identical profile state succeeds" 0
check_contains "identical profile state reports unchanged" 'Local selection unchanged.'
check_equal "no-change preserves state identity" "$(identity_of "$PROFILE_ROOT/dotfiles/active-selection.toml")" "$PROFILE_IDENTITY"
check_equal "no-change preserves state mode" "$(mode_of "$PROFILE_ROOT/dotfiles/active-selection.toml")" "$PROFILE_MODE"
check_equal "no-change preserves state bytes" "$(cksum "$PROFILE_ROOT/dotfiles/active-selection.toml")" "$PROFILE_CKSUM"

MODULE_ROOT="${TEST_ROOT}/module-state"
run_command env XDG_CONFIG_HOME="$MODULE_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules prompt.starship,shell.zsh --add shell.zsh.autosuggestions --platform macos
check_status "explicit module selection saves on macOS" 0
check_contains "module summary preserves requested base order" 'Base: modules prompt.starship,shell.zsh'
check_contains "module summary preserves addition order" 'Additional modules: shell.zsh.autosuggestions'
check_file_exact "module state preserves explicit intent without dependency expansion" "$MODULE_ROOT/dotfiles/active-selection.toml" "$MODULE_BODY"

PUBLIC_HOOK_ROOT="${TEST_ROOT}/public-hook-isolation"
run_command env XDG_CONFIG_HOME="$PUBLIC_HOOK_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" \
    DOTFILES_CONFIG_TEST_AFTER_LOCK_CREATE=unavailable_private_hook \
    DOTFILES_CONFIG_TEST_LOCK_IDENTITY_CAPTURE=unavailable_private_hook \
    DOTFILES_CONFIG_TEST_LOCK_IDENTITY_VALIDATION=unavailable_private_hook \
    "$CLI" config set --modules prompt.starship --platform debian
check_status "public config set cannot reach private lock failure seams" 0
check_file_exact "public hook isolation still saves canonical state" "$PUBLIC_HOOK_ROOT/dotfiles/active-selection.toml" "$ALTERNATE_BODY"
assert_no_owned_debris "public hook isolation leaves no owned debris" "$PUBLIC_HOOK_ROOT/dotfiles"

OVERLAP_ROOT="${TEST_ROOT}/profile-overlap"
run_command env XDG_CONFIG_HOME="$OVERLAP_ROOT" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --profile shell.minimal --add shell.zsh --platform debian
check_status "profile and dependency overlap remains valid" 0

run_command env XDG_CONFIG_HOME="${TEST_ROOT}/duplicate-base" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.zsh,shell.zsh --platform debian
check_status "duplicate base intent is invalid" 3
run_command env XDG_CONFIG_HOME="${TEST_ROOT}/duplicate-add" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.zsh --add prompt.starship,prompt.starship --platform debian
check_status "duplicate additional intent is invalid" 3
run_command env XDG_CONFIG_HOME="${TEST_ROOT}/duplicate-cross" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.zsh --add shell.zsh --platform debian
check_status "duplicate base and addition intent is invalid" 3
run_command env XDG_CONFIG_HOME="${TEST_ROOT}/unknown-module" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.unknown --platform debian
check_status "unknown proposed module is invalid" 3
run_command env XDG_CONFIG_HOME="${TEST_ROOT}/unsupported-module" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules terminal.ghostty --platform debian
check_status "unsupported proposed module is invalid" 3


VALID_FIXTURE=$(stage_fixture valid)
CYCLE_FIXTURE=$(stage_fixture cycle)
COLLISION_FIXTURE=$(stage_fixture source-collision)
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" XDG_CONFIG_HOME="${TEST_ROOT}/conflict" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules terminal.ghostty,terminal.wezterm --platform macos
check_status "exclusive-group conflict is rejected during save" 3
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" XDG_CONFIG_HOME="${TEST_ROOT}/declared-conflict" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.zsh,terminal.wezterm --platform macos
check_status "declared conflict is rejected during save" 3
run_command env DOTFILES_SOURCE_DIR="$CYCLE_FIXTURE" XDG_CONFIG_HOME="${TEST_ROOT}/cycle" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.alpha --platform debian
check_status "catalog dependency cycle is rejected during save" 3
run_command env DOTFILES_SOURCE_DIR="$COLLISION_FIXTURE" XDG_CONFIG_HOME="${TEST_ROOT}/collision" HOME="$PROFILE_HOME" DOTFILES_CHEZMOI_BIN="$CHEZMOI_PROBE" "$CLI" config set \
    --modules shell.alpha,shell.beta --platform debian
check_status "rendered-target ownership collision is rejected during save" 3

if [ ! -s "$PROBE_LOG" ]; then
    STATUS=0
    OUTPUT=
    pass "saving never invokes prerequisites, artifacts, providers, installers, editors, pagers, networks, or privilege helpers"
else
    STATUS=1
    OUTPUT=$(< "$PROBE_LOG")
    fail "saving never invokes prerequisites, artifacts, providers, installers, editors, pagers, networks, or privilege helpers"
fi
if [ -s "$CHEZMOI_LOG" ] && ! grep -Ev '(^| )execute-template( |$)' "$CHEZMOI_LOG" | grep -q . && \
    ! grep -E '(^| )(apply|diff|init|update|add|remove|purge|destroy|forget|execute|externals|encrypt|decrypt)( |$)' "$CHEZMOI_LOG" | grep -v 'execute-template' | grep -q .; then
    STATUS=0
    OUTPUT=
    pass "saving reaches only Chezmoi catalog template extraction"
else
    STATUS=1
    OUTPUT=$(< "$CHEZMOI_LOG")
    fail "saving reaches only Chezmoi catalog template extraction"
fi

