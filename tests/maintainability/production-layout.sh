loader_fixture="${TEST_ROOT}/duplicate loader"
mkdir -p "$loader_fixture"
cp -R "${PROJECT_ROOT}/lib" "$loader_fixture/lib"
printf '%s\n' 'source "$DOTFILES_CLI_LOADER_DIR/cli/common.sh"' >> "$loader_fixture/lib/cli.sh"
output=$(check_fixed_loaders "$loader_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'duplicate fixed-loader membership is rejected' 1
check_equal 'duplicate loader diagnostic names only the relative facade' "$output" \
    'error: fixed CLI loader order or membership is invalid: lib/cli.sh'
missing_loader_fixture="${TEST_ROOT}/missing loader leaf"
mkdir -p "$missing_loader_fixture"
cp -R "${PROJECT_ROOT}/lib" "$missing_loader_fixture/lib"
rm -f "$missing_loader_fixture/lib/cli/catalog.sh"
output=$(check_fixed_loaders "$missing_loader_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'missing fixed-loader membership is rejected' 1
check_equal 'missing loader diagnostic identifies only the relative leaf' "$output" \
    'error: fixed CLI loader leaf set is invalid: lib/cli
error: fixed CLI loader leaf is missing: lib/cli/catalog.sh'
unlisted_cli_fixture="${TEST_ROOT}/unlisted CLI leaf"
mkdir -p "$unlisted_cli_fixture"
cp -R "${PROJECT_ROOT}/lib" "$unlisted_cli_fixture/lib"
printf '%s\n' '# unlisted CLI fixture' > "$unlisted_cli_fixture/lib/cli/orphan.sh"
output=$(check_fixed_loaders "$unlisted_cli_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'unlisted CLI loader leaf is rejected' 1
check_equal 'unlisted CLI diagnostic identifies only the relative owned directory' "$output" \
    'error: fixed CLI loader leaf set is invalid: lib/cli'

unlisted_state_fixture="${TEST_ROOT}/unlisted config-state leaf"
mkdir -p "$unlisted_state_fixture"
cp -R "${PROJECT_ROOT}/lib" "$unlisted_state_fixture/lib"
printf '%s\n' '# unlisted config-state fixture' > \
    "$unlisted_state_fixture/lib/config-state/orphan.sh"
output=$(check_fixed_loaders "$unlisted_state_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'unlisted config-state loader leaf is rejected' 1
check_equal 'unlisted config-state diagnostic identifies only the relative owned directory' "$output" \
    'error: fixed config-state loader leaf set is invalid: lib/config-state'

dynamic_loader_fixture="${TEST_ROOT}/dynamic loader"
mkdir -p "$dynamic_loader_fixture"
cp -R "${PROJECT_ROOT}/lib" "$dynamic_loader_fixture/lib"
printf '%s\n' 'eval '\''source "$DOTFILES_CLI_LOADER_DIR/cli/common.sh"'\''' >> \
    "$dynamic_loader_fixture/lib/cli.sh"
output=$(check_fixed_loaders "$dynamic_loader_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'dynamic loader evaluation is rejected' 1
check_equal 'dynamic loader diagnostic identifies only the relative facade' "$output" \
    'error: dynamic CLI loader syntax is prohibited: lib/cli.sh'

leaf_source_fixture="${TEST_ROOT}/leaf source edge"
mkdir -p "$leaf_source_fixture"
cp -R "${PROJECT_ROOT}/lib" "$leaf_source_fixture/lib"
printf '%s\n' 'source "$DOTFILES_CLI_LOADER_DIR/cli/common.sh"' >> \
    "$leaf_source_fixture/lib/cli/catalog.sh"
output=$(check_fixed_loaders "$leaf_source_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'leaf-to-leaf source edges are rejected' 1
check_equal 'leaf source-edge diagnostic identifies only the relative leaf' "$output" \
    'error: CLI loader leaf contains a facade or sibling source edge: lib/cli/catalog.sh'

duplicate_fixture="${TEST_ROOT}/duplicate function"
mkdir -p "$duplicate_fixture/bin" "$duplicate_fixture/lib"
printf '%s\n' 'same_owner() {' '    :' '}' > "$duplicate_fixture/bin/dotfiles"
printf '%s\n' 'same_owner() {' '    :' '}' > "$duplicate_fixture/lib/example.sh"
output=$(check_duplicate_function_definitions "$duplicate_fixture" 2>&1)
status=$?
STATUS=$status
OUTPUT=$output
check_status 'duplicate production function definitions are rejected' 1
check_equal 'duplicate function diagnostic identifies both relative owners' "$output" \
    'error: duplicate production function same_owner: bin/dotfiles,lib/example.sh'
