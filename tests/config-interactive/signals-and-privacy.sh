# Assertions for interactive signals, non-invocation, and privacy.
new_case signal-hup
run_tty '[{"wait":"Base type (profile or modules):\n","signal":"HUP"}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "HUP while awaiting base returns 129" 129
check_path_absent "HUP while awaiting base creates no state" "$CASE_CONFIG"

new_case signal-int
run_tty '[{"wait":"Base type (profile or modules):\n","send":"profile"},{"wait":"Profile ID:\n","send":"shell.minimal"},{"wait":"Additional module IDs (comma-separated, empty for none):\n","signal":"INT"}]' "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "INT while awaiting additions returns 130" 130
check_path_absent "INT while awaiting additions creates no state" "$CASE_CONFIG"

new_case signal-term
EVENTS='[{"wait":"Base type (profile or modules):\n","send":"profile"},{"wait":"Profile ID:\n","send":"shell.minimal"},{"wait":"Additional module IDs (comma-separated, empty for none):\n","send":""},{"wait":"Save this local selection? Type yes to continue:\n","signal":"TERM"}]'
run_tty "$EVENTS" "$PROJECT_ROOT" "$CASE_CONFIG" "$CASE_HOME" config interactive --platform debian
check_status "TERM while awaiting confirmation returns 143" 143
check_path_absent "TERM while awaiting confirmation creates no state" "$CASE_CONFIG"

if [ ! -s "$PROBE_LOG" ]; then
    pass "interactive selection invokes no provider, prerequisite, installer, network, pager, editor, privilege, render, plan, apply, or cache helper"
else
    STATUS=1
    OUTPUT=$(< "$PROBE_LOG")
    fail "interactive selection invokes no provider, prerequisite, installer, network, pager, editor, privilege, render, plan, apply, or cache helper"
fi

if awk '$NF != "execute-template" { bad = 1 } END { exit bad }' "$CHEZMOI_LOG"; then
    pass "interactive selection reaches only Chezmoi catalog template extraction"
else
    STATUS=1
    OUTPUT=$(< "$CHEZMOI_LOG")
    fail "interactive selection reaches only Chezmoi catalog template extraction"
fi

OUTPUT=$ALL_OUTPUT
check_not_contains "interactive output hides raw test roots" "$TEST_ROOT"
check_not_contains "interactive output hides the username" "$(id -un)"
check_not_contains "interactive output hides the hostname" "$(hostname)"

if rg -n 'schema = [^1]|schema must be [^1]' "$PROJECT_ROOT/.chezmoidata" "$PROJECT_ROOT/lib/config-state.sh" >/dev/null 2>&1; then
    STATUS=1
    OUTPUT='non-schema-1 active catalog or state implementation found'
    fail "interactive selection preserves schema 1"
else
    pass "interactive selection preserves schema 1"
fi
