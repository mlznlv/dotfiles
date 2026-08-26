#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)
DOTFILES_TEST_SUITE_DIR="${SCRIPT_DIR}/config-inspection"
# test-suite-manifest: support.sh syntax-and-output.sh composition-and-precedence.sh path-and-state-safety.sh descriptors-drift-and-privacy.sh

source "$DOTFILES_TEST_SUITE_DIR/support.sh"
config_inspection_initialize
trap cleanup EXIT

source "$DOTFILES_TEST_SUITE_DIR/syntax-and-output.sh"
source "$DOTFILES_TEST_SUITE_DIR/composition-and-precedence.sh"
source "$DOTFILES_TEST_SUITE_DIR/path-and-state-safety.sh"
source "$DOTFILES_TEST_SUITE_DIR/descriptors-drift-and-privacy.sh"

if [ "$failures" -ne 0 ]; then
    printf '%s config-inspection checks, %s failures\n' "$checks" "$failures" >&2
    exit 1
fi

printf '%s config-inspection checks passed\n' "$checks"
