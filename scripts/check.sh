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
# Discover every source-only production module so a new fixed-tree leaf cannot
# bypass Bash syntax validation.
while IFS= read -r production_shell; do
    bash -n "$production_shell"
done < <(find "${PROJECT_ROOT}/lib" -type f -name '*.sh' -print | LC_ALL=C sort)
bash -n "${PROJECT_ROOT}/scripts/check.sh"
bash -n "${PROJECT_ROOT}/scripts/check-branch-policy.sh"
bash -n "${PROJECT_ROOT}/scripts/check-maintainability.sh"
# Syntax-check every runner, helper, support file, and case recursively. Only
# the stable top-level runners below are executed.
while IFS= read -r test_shell; do
    bash -n "$test_shell"
done < <(find "${PROJECT_ROOT}/tests" -type f -name '*.sh' -print | LC_ALL=C sort)
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/dotfiles-python-cache" python3 -m py_compile "${PROJECT_ROOT}/tests/helpers/pty-confirm.py"
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/dotfiles-python-cache" python3 -m py_compile "${PROJECT_ROOT}/tests/helpers/pty-interactive.py"

bash "${PROJECT_ROOT}/scripts/check-branch-policy.sh"
bash "${PROJECT_ROOT}/scripts/check-maintainability.sh"

"${PROJECT_ROOT}/bin/dotfiles" help >/dev/null
"${PROJECT_ROOT}/bin/dotfiles" version >/dev/null
"${PROJECT_ROOT}/bin/dotfiles" catalog validate >/dev/null

bash "${PROJECT_ROOT}/tests/run.sh"
bash "${PROJECT_ROOT}/tests/config-state.sh"
bash "${PROJECT_ROOT}/tests/config-interactive.sh"
bash "${PROJECT_ROOT}/tests/config-consumption.sh"
bash "${PROJECT_ROOT}/tests/config-inspection.sh"
bash "${PROJECT_ROOT}/tests/maintainability.sh"
bash "${PROJECT_ROOT}/tests/render.sh"
bash "${PROJECT_ROOT}/tests/plan.sh"
bash "${PROJECT_ROOT}/tests/apply.sh"
