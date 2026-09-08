#!/usr/bin/env bash

# Branch-policy guard. `master` is the active, stable, and only integration
# branch. This check fails closed when an active `next` integration policy, a
# non-`master` pull-request target, or a `legacy` workflow trigger is
# reintroduced.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

require_text() {
    file=$1
    text=$2
    if ! grep -Fq -- "${text}" "${PROJECT_ROOT}/${file}"; then
        printf 'error: %s must contain branch-policy text: %s\n' "${file}" "${text}" >&2
        exit 1
    fi
}

# Reject retired policy by pattern rather than by exact sentence. An exact-string
# check only catches the wording that happened to be removed, so a reworded
# reintroduction of `next` would pass.
forbid_pattern() {
    file=$1
    pattern=$2
    label=$3
    if grep -Eiq -- "${pattern}" "${PROJECT_ROOT}/${file}"; then
        printf 'error: %s reintroduces retired branch policy: %s\n' "${file}" "${label}" >&2
        exit 1
    fi
}

# Every branch named in a workflow trigger block must be master.
check_workflow_branches() {
    workflow=$1
    workflow_path="${PROJECT_ROOT}/.github/workflows/${workflow}"
    for event in pull_request push; do
        event_block=$(awk -v event="${event}:" '
            $0 == "  " event { active = 1; next }
            active && $0 ~ /^  [[:alnum:]_-]+:/ { exit }
            active { print }
        ' "${workflow_path}")

        if ! printf '%s\n' "${event_block}" | grep -Eq '^[[:space:]]+- master$'; then
            printf 'error: %s %s must cover master\n' "${workflow}" "${event}" >&2
            exit 1
        fi

        unexpected=$(printf '%s\n' "${event_block}" |
            grep -E '^[[:space:]]+- ' | grep -Ev '^[[:space:]]+- master$' || true)
        if [ -n "${unexpected}" ]; then
            printf 'error: %s %s triggers on a branch other than master:%s\n' \
                "${workflow}" "${event}" " $(printf '%s' "${unexpected}" | tr -s '[:space:]' ' ')" >&2
            exit 1
        fi
    done
}

require_text CONTRIBUTING.md '`master` is the active, stable, and only integration branch'
require_text CONTRIBUTING.md '`legacy` is a read-only recovery snapshot'
require_text CONTRIBUTING.md 'targets `master`'
require_text CONTRIBUTING.md 'deleted after merge'

# `next` is retired. Reject any reference to it as a branch, however worded, and
# any promotion route, in the files that carry active policy.
for policy_file in CONTRIBUTING.md .github/PULL_REQUEST_TEMPLATE.md; do
    forbid_pattern "${policy_file}" '`next`' 'a `next` branch reference'
    forbid_pattern "${policy_file}" '(next[^.]{0,40}branch|branch[^.]{0,40}\bnext\b)' \
        'next described as a branch'
    forbid_pattern "${policy_file}" 'promotion pull request' 'a promotion route'
done

require_text .github/dependabot.yml 'target-branch: master'
# Every declared target-branch must be master, not merely one of them.
dependabot_targets=$(grep -cE '^[[:space:]]*target-branch:' "${PROJECT_ROOT}/.github/dependabot.yml" || true)
dependabot_master=$(grep -cE '^[[:space:]]*target-branch:[[:space:]]*master[[:space:]]*$' \
    "${PROJECT_ROOT}/.github/dependabot.yml" || true)
if [ "${dependabot_targets}" -ne "${dependabot_master}" ]; then
    printf 'error: .github/dependabot.yml targets a branch other than master\n' >&2
    exit 1
fi

require_text .github/PULL_REQUEST_TEMPLATE.md 'targets `master`'
require_text .github/PULL_REQUEST_TEMPLATE.md 'This pull request does not target `legacy`.'

for workflow in ci.yml documentation.yml secret-scan.yml; do
    check_workflow_branches "${workflow}"
done

printf 'Branch policy checks passed.\n'
