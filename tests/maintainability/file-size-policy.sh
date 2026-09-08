fixture="${TEST_ROOT}/oversized fixture"
mkdir -p "$fixture/bin" "$fixture/lib"
awk 'BEGIN { for (line = 1; line <= 251; line++) print "# fixture" }' > "$fixture/bin/dotfiles"
awk 'BEGIN { for (line = 1; line <= 501; line++) print "# fixture" }' > "$fixture/lib/example.sh"
output=$(check_production_line_budgets "$fixture" 2>&1)
status=$?
expected='error: production shell line budget exceeded: bin/dotfiles has 251 lines (allowed 250)
error: production shell line budget exceeded: lib/example.sh has 501 lines (allowed 500)'
STATUS=$status
OUTPUT=$output
check_status 'synthetic oversized production files fail the line guard' 1
check_equal 'line-budget diagnostics are relative and measured' "$output" "$expected"
test_budget_fixture="${TEST_ROOT}/oversized test fixture"
mkdir -p "$test_budget_fixture/tests/example"
awk 'BEGIN { for (line = 1; line <= 151; line++) print "# fixture" }' > \
    "$test_budget_fixture/tests/example.sh"
awk 'BEGIN { for (line = 1; line <= 501; line++) print "# fixture" }' > \
    "$test_budget_fixture/tests/example/case.sh"
output=$(check_test_line_budgets "$test_budget_fixture" 2>&1)
status=$?
expected='error: test shell line budget exceeded: tests/example.sh has 151 lines (allowed 150)
error: test shell line budget exceeded: tests/example/case.sh has 501 lines (allowed 500)'
STATUS=$status
OUTPUT=$output
check_status 'synthetic oversized test runner and fragment fail the line guard' 1
check_equal 'test line-budget diagnostics are relative and measured' "$output" "$expected"
