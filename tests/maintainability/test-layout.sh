test_layout_fixture="${TEST_ROOT}/test loader fixture"
make_test_layout_fixture "$test_layout_fixture"
rm -f "$test_layout_fixture/tests/config-state/cli-and-persistence.sh"
check_layout_rejection 'missing test leaf is rejected' "$test_layout_fixture" \
    'error: fixed test loader leaf is missing: tests/config-state/cli-and-persistence.sh'

test_layout_fixture="${TEST_ROOT}/duplicate test loader fixture"
make_test_layout_fixture "$test_layout_fixture"
sed -i.bak 's/# test-suite-manifest: /# test-suite-manifest: support.sh /' \
    "$test_layout_fixture/tests/config-state.sh"
rm -f "$test_layout_fixture/tests/config-state.sh.bak"
check_layout_rejection 'duplicate test loader membership is rejected' "$test_layout_fixture" \
    'error: duplicate fixed test loader membership: tests/config-state.sh'

test_layout_fixture="${TEST_ROOT}/unlisted test leaf fixture"
make_test_layout_fixture "$test_layout_fixture"
printf '%s\n' '# unlisted fixture' > "$test_layout_fixture/tests/config-state/unlisted.sh"
check_layout_rejection 'unlisted test leaf is rejected' "$test_layout_fixture" \
    'error: fixed test loader leaf set is invalid: tests/config-state'

test_layout_fixture="${TEST_ROOT}/dynamic test loader fixture"
make_test_layout_fixture "$test_layout_fixture"
printf '%s\n' 'source "$DOTFILES_TEST_SUITE_DIR/"*.sh' \
    'source "$DOTFILES_TEST_SUITE_DIR/${DOTFILES_TEST_CASE}.sh"' 'source ./case.sh' >> \
    "$test_layout_fixture/tests/config-state.sh"
check_layout_rejection 'wildcard, environment-selected, and current-directory test loads are rejected' \
    "$test_layout_fixture" 'error: fixed test loader order or membership is invalid: tests/config-state.sh'

test_layout_fixture="${TEST_ROOT}/sibling test leaf fixture"
make_test_layout_fixture "$test_layout_fixture"
printf '%s\n' 'source "$DOTFILES_TEST_SUITE_DIR/path-and-state-validation.sh"' >> \
    "$test_layout_fixture/tests/config-state/cli-and-persistence.sh"
check_layout_rejection 'sibling-loaded test leaf is rejected' "$test_layout_fixture" \
    'error: test leaf contains a sibling or dynamic source edge: tests/config-state/cli-and-persistence.sh'

test_layout_fixture="${TEST_ROOT}/circular test leaf fixture"
make_test_layout_fixture "$test_layout_fixture"
printf '%s\n' 'source "$DOTFILES_TEST_SUITE_DIR/../config-state.sh"' >> \
    "$test_layout_fixture/tests/config-state/cli-and-persistence.sh"
check_layout_rejection 'circular test source edge is rejected' "$test_layout_fixture" \
    'error: test leaf contains a sibling or dynamic source edge: tests/config-state/cli-and-persistence.sh'

test_layout_fixture="${TEST_ROOT}/duplicate test function fixture"
make_test_layout_fixture "$test_layout_fixture"
printf '%s\n' 'function case_helper { :; }' 'pass() { :; }' >> "$test_layout_fixture/tests/config-state/cli-and-persistence.sh"
check_layout_rejection 'case-owned suite-local test function is rejected' "$test_layout_fixture" \
    'error: test case defines a suite-local function: tests/config-state/cli-and-persistence.sh'
check_layout_rejection 'duplicate suite-local test function is rejected' "$test_layout_fixture" \
    'error: duplicate test function pass: tests/config-state'

test_layout_fixture="${TEST_ROOT}/unsafe support fixture"
make_test_layout_fixture "$test_layout_fixture"
printf '%s\n' 'printf "unexpected support output\\n"' >> \
    "$test_layout_fixture/tests/config-state/support.sh"
check_layout_rejection 'support source-time side effects are rejected' "$test_layout_fixture" \
    'error: test support is not source-safe: tests/config-state/support.sh'

test_layout_fixture="${TEST_ROOT}/executable fragment fixture"
make_test_layout_fixture "$test_layout_fixture"
chmod +x "$test_layout_fixture/tests/config-state/cli-and-persistence.sh"
chmod 755 "$test_layout_fixture/tests/config-state.sh"
check_layout_rejection 'executable internal test fragment is rejected' "$test_layout_fixture" \
    'error: internal test fragment must not be executable: tests/config-state/cli-and-persistence.sh'
check_contains 'stable test runner mode changes are rejected' \
    'error: stable test runner mode is invalid: tests/config-state.sh'
sed -i.bak 's/^trap cleanup EXIT$/# delayed cleanup trap/' \
    "$test_layout_fixture/tests/config-state.sh"
rm -f "$test_layout_fixture/tests/config-state.sh.bak"
check_layout_rejection 'delayed initialization cleanup is rejected' "$test_layout_fixture" \
    'error: test runner cleanup must immediately protect initialization: tests/config-state.sh'
test_syntax_fixture="${TEST_ROOT}/invalid test syntax"
mkdir -p "$test_syntax_fixture/tests"
printf '%s\n' 'if true; then' > "$test_syntax_fixture/tests/invalid.sh"
output=$(check_test_syntax "$test_syntax_fixture" 2>&1)
STATUS=$?
OUTPUT=$output
check_status 'recursive test syntax failure is rejected' 1
check_equal 'test syntax diagnostic is repository-relative' "$output" \
    'error: test shell syntax is invalid: tests/invalid.sh'
test_execution_fixture="${TEST_ROOT}/direct fragment execution"
mkdir -p "$test_execution_fixture/scripts"
cp "${PROJECT_ROOT}/scripts/check.sh" "$test_execution_fixture/scripts/check.sh"
printf '%s\n' 'bash "${PROJECT_ROOT}/tests/apply/recomputation-and-failures.sh"' >> \
    "$test_execution_fixture/scripts/check.sh"
output=$(check_test_execution_manifest "$test_execution_fixture" 2>&1)
STATUS=$?
OUTPUT=$output
check_status 'direct execution of an internal test fragment is rejected' 1
check_equal 'test execution diagnostic names only the stable check runner' "$output" \
    'error: stable test execution manifest is invalid: scripts/check.sh'
output=$(check_test_line_budgets "$PROJECT_ROOT" 2>&1); STATUS=$?; OUTPUT=$output
check_status 'final recursive test tree passes all line budgets' 0
check_equal 'successful recursive test line guard is silent' "$output" ''
