#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)
DOTFILES_TEST_SUITE_DIR="${SCRIPT_DIR}/config-consumption"
# test-suite-manifest: support.sh syntax-and-precedence.sh equivalence-and-apply.sh state-safety.sh reader-drift-and-privacy.sh

source "$DOTFILES_TEST_SUITE_DIR/support.sh"
config_consumption_initialize
trap cleanup EXIT

source "$DOTFILES_TEST_SUITE_DIR/syntax-and-precedence.sh"
source "$DOTFILES_TEST_SUITE_DIR/equivalence-and-apply.sh"
source "$DOTFILES_TEST_SUITE_DIR/state-safety.sh"
source "$DOTFILES_TEST_SUITE_DIR/reader-drift-and-privacy.sh"

if [ "$failures" -ne 0 ]; then
    printf '%s config-consumption checks, %s failures\n' "$checks" "$failures" >&2
    exit 1
fi

printf '%s config-consumption checks passed\n' "$checks"
