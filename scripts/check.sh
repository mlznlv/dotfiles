#!/usr/bin/env bash

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

unexpected_fixture_data=$(find "${PROJECT_ROOT}/tests" -type d -name '.chezmoidata' -print -quit)
if [ -n "${unexpected_fixture_data}" ]; then
    printf 'error: test fixtures must not contain nested .chezmoidata directories: %s\n' "${unexpected_fixture_data}" >&2
    exit 1
fi

bash -n "${PROJECT_ROOT}/bin/dotfiles"
bash -n "${PROJECT_ROOT}/scripts/check.sh"
bash -n "${PROJECT_ROOT}/scripts/check-branch-policy.sh"
bash -n "${PROJECT_ROOT}/tests/run.sh"
bash -n "${PROJECT_ROOT}/lib/render.sh"
bash -n "${PROJECT_ROOT}/lib/plan.sh"
bash -n "${PROJECT_ROOT}/lib/apply.sh"
bash -n "${PROJECT_ROOT}/lib/config-state.sh"
bash -n "${PROJECT_ROOT}/tests/render.sh"
bash -n "${PROJECT_ROOT}/tests/helpers/chezmoi-render-probe.sh"
bash -n "${PROJECT_ROOT}/tests/plan.sh"
bash -n "${PROJECT_ROOT}/tests/helpers/chezmoi-plan-probe.sh"
bash -n "${PROJECT_ROOT}/tests/apply.sh"
bash -n "${PROJECT_ROOT}/tests/config-state.sh"
bash -n "${PROJECT_ROOT}/tests/helpers/chezmoi-apply-probe.sh"
bash -n "${PROJECT_ROOT}/tests/helpers/apply-confirmation-hook.sh"
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/dotfiles-python-cache" python3 -m py_compile "${PROJECT_ROOT}/tests/helpers/pty-confirm.py"

bash "${PROJECT_ROOT}/scripts/check-branch-policy.sh"

"${PROJECT_ROOT}/bin/dotfiles" help >/dev/null
"${PROJECT_ROOT}/bin/dotfiles" version >/dev/null
"${PROJECT_ROOT}/bin/dotfiles" catalog validate >/dev/null

bash "${PROJECT_ROOT}/tests/run.sh"
bash "${PROJECT_ROOT}/tests/config-state.sh"
bash "${PROJECT_ROOT}/tests/render.sh"
bash "${PROJECT_ROOT}/tests/plan.sh"
bash "${PROJECT_ROOT}/tests/apply.sh"
