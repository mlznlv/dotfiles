#!/usr/bin/env bash

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

bash -n "${PROJECT_ROOT}/bin/dotfiles"
bash -n "${PROJECT_ROOT}/scripts/check.sh"
bash -n "${PROJECT_ROOT}/tests/run.sh"

"${PROJECT_ROOT}/bin/dotfiles" help >/dev/null
"${PROJECT_ROOT}/bin/dotfiles" version >/dev/null
"${PROJECT_ROOT}/bin/dotfiles" catalog validate >/dev/null

bash "${PROJECT_ROOT}/tests/run.sh"
