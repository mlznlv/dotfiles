#!/usr/bin/env bash

# Focused suite for the single-branch policy and the Claude command allowlist.
# It asserts current policy only; historical records in accepted ADRs are
# checked to remain untouched rather than rewritten.

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-branch-policy.XXXXXX")
cleanup() {
    rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

checks=0
failures=0

pass() {
    checks=$((checks + 1))
    printf 'ok - %s\n' "$1"
}

fail() {
    checks=$((checks + 1))
    failures=$((failures + 1))
    printf 'not ok - %s\n' "$1"
    [ "$#" -gt 1 ] && printf '  %s\n' "$2"
}

assert_contains() {
    if grep -Fq -- "$3" "${PROJECT_ROOT}/$2"; then
        pass "$1"
    else
        fail "$1" "missing in $2: $3"
    fi
}

assert_absent() {
    if grep -Fq -- "$3" "${PROJECT_ROOT}/$2"; then
        fail "$1" "unexpected in $2: $3"
    else
        pass "$1"
    fi
}

# --- master is the only base and target -----------------------------------

assert_contains 'contributing names master the only integration branch' \
    CONTRIBUTING.md '`master` is the active, stable, and only integration branch'
assert_contains 'contributing requires targeting master' \
    CONTRIBUTING.md 'targets `master`'
assert_contains 'contributing keeps legacy read-only' \
    CONTRIBUTING.md '`legacy` is a read-only recovery snapshot'
assert_contains 'contributing requires task branches to be deleted' \
    CONTRIBUTING.md 'deleted after merge'

for retired in \
    '`next` is the active integration branch' \
    'target their pull requests to `next`' \
    'promotion pull request from `next`' \
    'integrate into `next`'; do
    assert_absent 'contributing declares no active next policy' CONTRIBUTING.md "$retired"
done

# --- dependabot ------------------------------------------------------------

assert_contains 'dependabot targets master' .github/dependabot.yml 'target-branch: master'
assert_absent 'dependabot does not target next' .github/dependabot.yml 'target-branch: next'
assert_absent 'dependabot does not target legacy' .github/dependabot.yml 'target-branch: legacy'

# --- workflow triggers -----------------------------------------------------

for workflow in ci documentation secret-scan; do
    path=".github/workflows/${workflow}.yml"
    master_triggers=$(grep -c '^      - master$' "${PROJECT_ROOT}/${path}" || true)
    if [ "$master_triggers" -eq 2 ]; then
        pass "${workflow} covers master for push and pull_request"
    else
        fail "${workflow} covers master for push and pull_request" \
            "expected 2 master triggers, found ${master_triggers}"
    fi
    assert_absent "${workflow} does not trigger on next" "$path" '- next'
    assert_absent "${workflow} does not trigger on legacy" "$path" '- legacy'
done

# --- pull-request template -------------------------------------------------

assert_contains 'template requires a master target' \
    .github/PULL_REQUEST_TEMPLATE.md 'targets `master`'
assert_contains 'template keeps the legacy guard' \
    .github/PULL_REQUEST_TEMPLATE.md 'This pull request does not target `legacy`.'
assert_absent 'template drops the next promotion route' \
    .github/PULL_REQUEST_TEMPLATE.md 'from `next` to `master`'

# --- contributor and agent guidance ---------------------------------------

assert_contains 'CLAUDE.md names master the only integration branch' \
    CLAUDE.md '`master` is the active, stable, and only integration branch'
assert_contains 'the contribution agent audits against master' \
    .claude/agents/contribution-check.md 'targeted at `master`'

# --- historical records stay historical ------------------------------------

if grep -Fq '`next` is the integration branch' \
    "${PROJECT_ROOT}/docs/adr/0009-define-pre-release-schema-versioning.md"; then
    pass 'accepted ADR history is preserved rather than rewritten'
else
    fail 'accepted ADR history is preserved rather than rewritten' \
        'ADR 0009 no longer records the branch model of its decision date'
fi

# --- the guard fails closed ------------------------------------------------

stage_policy_fixture() {
    fixture="${TEST_ROOT}/$1"
    mkdir -p "${fixture}/scripts" "${fixture}/.github/workflows"
    cp "${PROJECT_ROOT}/scripts/check-branch-policy.sh" "${fixture}/scripts/"
    cp "${PROJECT_ROOT}/CONTRIBUTING.md" "${fixture}/"
    cp "${PROJECT_ROOT}/.github/dependabot.yml" "${fixture}/.github/"
    cp "${PROJECT_ROOT}/.github/PULL_REQUEST_TEMPLATE.md" "${fixture}/.github/"
    cp "${PROJECT_ROOT}"/.github/workflows/*.yml "${fixture}/.github/workflows/"
    printf '%s\n' "${fixture}"
}

expect_guard_status() {
    name=$1
    expected=$2
    fixture=$3
    bash "${fixture}/scripts/check-branch-policy.sh" >/dev/null 2>&1
    actual=$?
    if [ "$actual" -eq "$expected" ]; then
        pass "$name"
    else
        fail "$name" "expected exit ${expected}, got ${actual}"
    fi
}

baseline=$(stage_policy_fixture baseline)
expect_guard_status 'guard passes on the current policy' 0 "$baseline"

reinstated=$(stage_policy_fixture reinstated-next)
printf '\n- `next` is the active integration branch\n' >> "${reinstated}/CONTRIBUTING.md"
expect_guard_status 'guard fails when next is reinstated as active policy' 1 "$reinstated"

retargeted=$(stage_policy_fixture dependabot-next)
sed -i.bak 's/target-branch: master/target-branch: next/' "${retargeted}/.github/dependabot.yml"
rm -f "${retargeted}/.github/dependabot.yml.bak"
expect_guard_status 'guard fails when dependabot retargets away from master' 1 "$retargeted"

legacy_trigger=$(stage_policy_fixture legacy-trigger)
sed -i.bak 's/^      - master$/      - master\n      - legacy/' \
    "${legacy_trigger}/.github/workflows/ci.yml"
rm -f "${legacy_trigger}/.github/workflows/ci.yml.bak"
expect_guard_status 'guard fails when a workflow triggers on legacy' 1 "$legacy_trigger"

promotion=$(stage_policy_fixture promotion-route)
printf '\nPromotion: the pull request is from `next` to `master`.\n' \
    >> "${promotion}/.github/PULL_REQUEST_TEMPLATE.md"
expect_guard_status 'guard fails when the next promotion route returns' 1 "$promotion"

# --- Claude configuration safety -------------------------------------------

SETTINGS="${PROJECT_ROOT}/.claude/settings.json"

if jq empty "$SETTINGS" >/dev/null 2>&1; then
    pass 'claude settings are valid JSON'
else
    fail 'claude settings are valid JSON'
fi

if bash -n "${PROJECT_ROOT}/.claude/hooks/verify-edit.sh" >/dev/null 2>&1; then
    pass 'claude hook shell syntax is valid'
else
    fail 'claude hook shell syntax is valid'
fi

allowed=$(jq -r '.permissions.allow[]' "$SETTINGS")
denied=$(jq -r '.permissions.deny[]' "$SETTINGS")

if printf '%s\n' "$allowed" | grep -Fqx 'Bash(./bin/dotfiles *)'; then
    fail 'no wildcard grants the whole CLI' 'Bash(./bin/dotfiles *) is allowed'
else
    pass 'no wildcard grants the whole CLI'
fi

# Every allowed dotfiles rule must name a known read-only subcommand.
READ_ONLY_SUBCOMMANDS='help version catalog module profile resolve prerequisite plan'
unexpected=''
while IFS= read -r rule; do
    case "$rule" in
        'Bash(./bin/dotfiles '*)
            remainder=${rule#'Bash(./bin/dotfiles '}
            remainder=${remainder%')'}
            subcommand=${remainder%% *}
            case " ${READ_ONLY_SUBCOMMANDS} " in
                *" ${subcommand} "*) ;;
                *)
                    if [ "$subcommand" = "config" ]; then
                        second=${remainder#config }
                        second=${second%% *}
                        case "$second" in
                            inspect|doctor) ;;
                            *) unexpected="${unexpected}${rule}
" ;;
                        esac
                    else
                        unexpected="${unexpected}${rule}
"
                    fi
                    ;;
            esac
            ;;
    esac
done <<EOF
${allowed}
EOF

if [ -z "$unexpected" ]; then
    pass 'every allowed dotfiles command is explicitly read-only'
else
    fail 'every allowed dotfiles command is explicitly read-only' \
        "$(printf '%s' "$unexpected" | tr '\n' ' ')"
fi

for mutating in \
    './bin/dotfiles apply' \
    './bin/dotfiles config set' \
    './bin/dotfiles config interactive'; do
    if printf '%s\n' "$allowed" | grep -Fq -- "$mutating"; then
        fail "mutating command is not allowed: ${mutating}"
    else
        pass "mutating command is not allowed: ${mutating}"
    fi
    if printf '%s\n' "$denied" | grep -Fq -- "$mutating"; then
        pass "mutating command is explicitly denied: ${mutating}"
    else
        fail "mutating command is explicitly denied: ${mutating}"
    fi
done

for provider in chezmoi brew mise; do
    if printf '%s\n' "$denied" | grep -Fq "Bash(${provider} *)"; then
        pass "direct ${provider} invocation is denied"
    else
        fail "direct ${provider} invocation is denied"
    fi
done

if [ "$failures" -ne 0 ]; then
    printf '%s of %s branch-policy checks failed\n' "$failures" "$checks" >&2
    exit 1
fi

printf '%s branch-policy checks passed\n' "$checks"
