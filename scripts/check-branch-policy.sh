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

forbid_text() {
    file=$1
    text=$2
    if grep -Fq -- "${text}" "${PROJECT_ROOT}/${file}"; then
        printf 'error: %s must not contain retired branch-policy text: %s\n' "${file}" "${text}" >&2
        exit 1
    fi
}

require_text CONTRIBUTING.md '`master` is the active, stable, and only integration branch'
require_text CONTRIBUTING.md '`legacy` is a read-only recovery snapshot'
require_text CONTRIBUTING.md 'targets `master`'
require_text CONTRIBUTING.md 'deleted after merge'

# `next` is retired. Reject any wording that restores it as an active base,
# target, or promotion route.
forbid_text CONTRIBUTING.md '`next` is the active integration branch'
forbid_text CONTRIBUTING.md 'target their pull requests to `next`'
forbid_text CONTRIBUTING.md 'promotion pull request from `next`'
forbid_text CONTRIBUTING.md 'integrate into `next`'

require_text .github/dependabot.yml 'target-branch: master'
forbid_text .github/dependabot.yml 'target-branch: next'
forbid_text .github/dependabot.yml 'target-branch: legacy'

require_text .github/PULL_REQUEST_TEMPLATE.md 'targets `master`'
require_text .github/PULL_REQUEST_TEMPLATE.md 'This pull request does not target `legacy`.'
forbid_text .github/PULL_REQUEST_TEMPLATE.md 'from `next` to `master`'
forbid_text .github/PULL_REQUEST_TEMPLATE.md 'targets `next`'

for workflow in ci.yml documentation.yml secret-scan.yml; do
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

        for branch in next legacy; do
            if printf '%s\n' "${event_block}" | grep -Eq "^[[:space:]]+- ${branch}$"; then
                printf 'error: %s %s must not cover %s\n' "${workflow}" "${event}" "${branch}" >&2
                exit 1
            fi
        done
    done
done

printf 'Branch policy checks passed.\n'
