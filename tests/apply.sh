#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)
DOTFILES_TEST_SUITE_DIR="${SCRIPT_DIR}/apply"
# test-suite-manifest: support.sh syntax-and-confirmation.sh convergence-and-scope.sh recomputation-and-failures.sh signals-privacy-and-cleanup.sh

source "$DOTFILES_TEST_SUITE_DIR/support.sh"
apply_allocate_root
trap cleanup EXIT
apply_initialize

source "$DOTFILES_TEST_SUITE_DIR/syntax-and-confirmation.sh"
source "$DOTFILES_TEST_SUITE_DIR/convergence-and-scope.sh"
source "$DOTFILES_TEST_SUITE_DIR/recomputation-and-failures.sh"
source "$DOTFILES_TEST_SUITE_DIR/signals-privacy-and-cleanup.sh"

if [ "$failures" -ne 0 ]; then
    printf '%s of %s apply checks failed\n' "$failures" "$checks" >&2
    exit 1
fi

printf '%s apply checks passed\n' "$checks"
