#!/usr/bin/env bash

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

require_text() {
    file=$1
    text=$2
    if ! grep -Fq -- "${text}" "${PROJECT_ROOT}/${file}"; then
        printf 'error: %s must contain branch-policy text: %s\n' "${file}" "${text}" >&2
        exit 1
    fi
}

require_text CONTRIBUTING.md '`master` is the stable, released branch'
require_text CONTRIBUTING.md '`next` is the active integration branch'
require_text CONTRIBUTING.md '`legacy` is a read-only recovery snapshot'
require_text CONTRIBUTING.md 'Never squash-merge or rebase'
require_text CONTRIBUTING.md 'do not merge `master` back into `next` or reset `next`'
require_text .github/dependabot.yml 'target-branch: next'
require_text .github/PULL_REQUEST_TEMPLATE.md 'This pull request does not target `legacy`.'
require_text .github/PULL_REQUEST_TEMPLATE.md 'Promotion: the pull request is from `next` to `master`'

for workflow in ci.yml documentation.yml secret-scan.yml; do
    workflow_path="${PROJECT_ROOT}/.github/workflows/${workflow}"
    for event in pull_request push; do
        event_block=$(awk -v event="${event}:" '
            $0 == "  " event { active = 1; next }
            active && $0 ~ /^  [[:alnum:]_-]+:/ { exit }
            active { print }
        ' "${workflow_path}")

        for branch in next master; do
            if ! printf '%s\n' "${event_block}" | grep -Eq "^[[:space:]]+- ${branch}$"; then
                printf 'error: %s %s must cover %s\n' "${workflow}" "${event%:}" "${branch}" >&2
                exit 1
            fi
        done

        if printf '%s\n' "${event_block}" | grep -Eq '^[[:space:]]+- legacy$'; then
            printf 'error: %s %s must not cover legacy\n' "${workflow}" "${event%:}" >&2
            exit 1
        fi
    done
done

printf 'Branch policy checks passed.\n'
