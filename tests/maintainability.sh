#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)
DOTFILES_TEST_SUITE_DIR="${SCRIPT_DIR}/maintainability"
# test-suite-manifest: support.sh file-size-policy.sh test-layout.sh production-layout.sh execution-and-portability.sh
# shellcheck source=maintainability/support.sh
source "$DOTFILES_TEST_SUITE_DIR/support.sh"
maintainability_allocate_root
trap cleanup EXIT
maintainability_initialize

# shellcheck source=maintainability/file-size-policy.sh
source "$DOTFILES_TEST_SUITE_DIR/file-size-policy.sh"
# shellcheck source=maintainability/test-layout.sh
source "$DOTFILES_TEST_SUITE_DIR/test-layout.sh"
# shellcheck source=maintainability/production-layout.sh
source "$DOTFILES_TEST_SUITE_DIR/production-layout.sh"
# shellcheck source=maintainability/execution-and-portability.sh
source "$DOTFILES_TEST_SUITE_DIR/execution-and-portability.sh"

if [ "$failures" -ne 0 ]; then
    printf '%s maintainability checks, %s failures\n' "$checks" "$failures"
    exit 1
fi

printf '%s maintainability checks passed\n' "$checks"
