# Assertions for explicit/local composition and catalog precedence.
MODULE_ROOT=$(new_root modules)
MODULE_HOME=$(new_home modules)
write_state "$MODULE_ROOT" "$MODULE_BODY"
MODULE_BEFORE=$(state_snapshot "$MODULE_ROOT")
run_cli "$MODULE_ROOT" "$MODULE_HOME" config inspect --platform macos
check_equal 'ordered module inspection output is exact' "$STDOUT" "$MODULE_MACOS_OUTPUT"
run_cli "$MODULE_ROOT" "$MODULE_HOME" config doctor --platform macos
check_equal 'healthy module doctor output is exact' "$STDOUT" 'Local selection file: healthy
Schema: 1
Composition for macos: valid'
run_cli "$MODULE_ROOT" "$MODULE_HOME" config inspect --platform debian
check_equal 'ordered module inspection is exact on Debian' "$STDOUT" "${MODULE_MACOS_OUTPUT//macos/debian}"
run_cli "$MODULE_ROOT" "$MODULE_HOME" config doctor --platform debian
check_equal 'healthy module doctor output is exact on Debian' "$STDOUT" 'Local selection file: healthy
Schema: 1
Composition for debian: valid'
check_equal 'module inspect and doctor preserve state metadata and tree' "$(state_snapshot "$MODULE_ROOT")" "$MODULE_BEFORE"

run_cli "$MISSING_ROOT" "$MISSING_HOME" config inspect --profile shell.minimal --platform debian
check_status 'explicit profile inspection bypasses missing state' 0
check_equal 'explicit profile uses invocation source and exact base' "$STDOUT" "${PROFILE_DEBIAN_OUTPUT/Selection source: local/Selection source: invocation}"
run_cli "$MISSING_ROOT" "$MISSING_HOME" config inspect --modules prompt.starship,shell.zsh --add shell.zsh.autosuggestions --platform macos
check_status 'explicit modules inspection bypasses missing state' 0
check_equal 'explicit modules preserve invocation base and additions' "$STDOUT" "${MODULE_MACOS_OUTPUT/Selection source: local/Selection source: invocation}"
[ ! -e "$MISSING_ROOT" ] && pass 'explicit inspection never derives or creates local state' || { STATUS=1; OUTPUT='root created'; fail 'explicit inspection never derives or creates local state'; }

ADDITIONAL_ROOT=$(new_root additional)
ADDITIONAL_HOME=$(new_home additional)
write_state "$ADDITIONAL_ROOT" "$ADDITIONAL_BODY"
ADDITIONAL_BEFORE=$(state_snapshot "$ADDITIONAL_ROOT")
run_cli "$ADDITIONAL_ROOT" "$ADDITIONAL_HOME" config inspect --add shell.zsh.autosuggestions --platform debian
check_status 'invocation addition appends to saved additions' 0
check_equal 'local-plus-invocation source and effective addition order are exact' "$STDOUT" 'Selection source: local plus invocation additions
Base: shell.zsh
Additional modules: prompt.starship,shell.zsh.autosuggestions
Resolved modules for debian:
  shell.zsh
  prompt.starship
  shell.zsh.autosuggestions'
check_equal 'inspection additions are never persisted' "$(state_snapshot "$ADDITIONAL_ROOT")" "$ADDITIONAL_BEFORE"

INVALID_ROOT=$(new_root invalid-bypass)
INVALID_HOME=$(new_home invalid-bypass)
write_state "$INVALID_ROOT" 'private-invalid-state-must-not-be-read'
INVALID_BEFORE=$(state_snapshot "$INVALID_ROOT")
run_cli "$INVALID_ROOT" "$INVALID_HOME" config inspect --modules prompt.starship --platform debian
check_status 'explicit inspect bypasses invalid local state' 0
check_equal 'invalid-state bypass output matches missing-state bypass' "$STDOUT" 'Selection source: invocation
Base: prompt.starship
Additional modules: none
Resolved modules for debian:
  prompt.starship'
check_not_contains 'explicit bypass never exposes invalid state bytes' 'private-invalid-state-must-not-be-read'
check_equal 'explicit bypass leaves invalid state untouched' "$(state_snapshot "$INVALID_ROOT")" "$INVALID_BEFORE"

ISOLATED="${TEST_ROOT}/isolated-project"
mkdir -p "$ISOLATED/bin" "$ISOLATED/lib"
cp "$CLI" "$ISOLATED/bin/dotfiles"
cp "${PROJECT_ROOT}/lib/cli.sh" "$ISOLATED/lib/cli.sh"
cp -R "${PROJECT_ROOT}/lib/cli" "$ISOLATED/lib/cli"
cp "${PROJECT_ROOT}/lib/catalog-records.tmpl" "${PROJECT_ROOT}/lib/catalog.awk" "$ISOLATED/lib/"
cp -R "${PROJECT_ROOT}/lib/catalog" "$ISOLATED/lib/catalog"
run_command env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$ISOLATED/bin/dotfiles" config inspect --modules prompt.starship --platform debian
check_status 'explicit inspect works without the config-state component' 0
check_equal 'component-free explicit inspect remains exact' "$STDOUT" 'Selection source: invocation
Base: prompt.starship
Additional modules: none
Resolved modules for debian:
  prompt.starship'
run_command env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$ISOLATED/bin/dotfiles" config inspect --platform debian
check_status 'local inspect requires the config-state component' 4
run_command env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$ISOLATED/bin/dotfiles" config doctor --platform debian
check_status 'doctor requires the config-state component' 4

cp "${PROJECT_ROOT}/lib/config-state.sh" "$ISOLATED/lib/config-state.sh"
cp -R "${PROJECT_ROOT}/lib/config-state" "$ISOLATED/lib/config-state"
rm -f "$ISOLATED/lib/catalog.awk"
run_command env DOTFILES_SOURCE_DIR="$PROJECT_ROOT" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$PROFILE_ROOT" HOME="$PROFILE_HOME" \
    "$ISOLATED/bin/dotfiles" config doctor --platform debian
check_status 'doctor requires the catalog component' 4
assert_no_summary 'missing catalog component emits no healthy summary'

run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --modules shell.zsh,shell.zsh --platform debian
check_status 'duplicate explicit input is invalid composition' 3
assert_no_summary 'duplicate explicit failure emits no inspect summary'
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --modules shell.unknown --platform debian
check_status 'unknown explicit identifier is invalid composition' 3
assert_no_summary 'unknown identifier failure emits no inspect summary'
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --modules terminal.ghostty --platform debian
check_status 'unsupported module/platform is invalid composition' 3
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config inspect --platform linux
check_status 'unsupported inspect platform is status 3' 3
run_cli "$PROFILE_ROOT" "$PROFILE_HOME" config doctor --platform linux
check_status 'unsupported doctor platform is status 3' 3

VALID_FIXTURE=$(stage_fixture valid)
CYCLE_FIXTURE=$(stage_fixture cycle)
COLLISION_FIXTURE=$(stage_fixture source-collision)
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config inspect --modules terminal.ghostty,terminal.wezterm --platform macos
check_status 'inspect rejects exclusive-group conflicts' 3
assert_no_summary 'exclusive-group failure emits no inspect summary'
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config inspect --modules shell.zsh,terminal.wezterm --platform macos
check_status 'inspect rejects declared conflicts' 3
run_command env DOTFILES_SOURCE_DIR="$CYCLE_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config inspect --modules shell.alpha --platform debian
check_status 'inspect rejects dependency cycles' 3
run_command env DOTFILES_SOURCE_DIR="$COLLISION_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$MISSING_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config inspect --modules shell.alpha,shell.beta --platform debian
check_status 'inspect rejects rendered-target ownership collisions' 3

DOCTOR_CONFLICT_ROOT=$(new_root doctor-conflict)
write_state "$DOCTOR_CONFLICT_ROOT" 'schema = 1

[selection]
modules = ["terminal.ghostty", "terminal.wezterm"]
additional_modules = []'
run_command env DOTFILES_SOURCE_DIR="$VALID_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$DOCTOR_CONFLICT_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config doctor --platform macos
check_status 'doctor rejects saved exclusive-group conflicts' 3
assert_no_summary 'saved conflict diagnosis emits no healthy summary'
DOCTOR_CYCLE_ROOT=$(new_root doctor-cycle)
write_state "$DOCTOR_CYCLE_ROOT" 'schema = 1

[selection]
modules = ["shell.alpha"]
additional_modules = []'
run_command env DOTFILES_SOURCE_DIR="$CYCLE_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$DOCTOR_CYCLE_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config doctor --platform debian
check_status 'doctor rejects saved dependency cycles' 3
DOCTOR_COLLISION_ROOT=$(new_root doctor-collision)
write_state "$DOCTOR_COLLISION_ROOT" 'schema = 1

[selection]
modules = ["shell.alpha", "shell.beta"]
additional_modules = []'
run_command env DOTFILES_SOURCE_DIR="$COLLISION_FIXTURE" DOTFILES_CHEZMOI_BIN="$REAL_CHEZMOI" XDG_CONFIG_HOME="$DOCTOR_COLLISION_ROOT" HOME="$MISSING_HOME" \
    "$CLI" config doctor --platform debian
check_status 'doctor rejects saved rendered-target ownership collisions' 3
