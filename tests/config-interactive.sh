#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)
DOTFILES_TEST_SUITE_DIR="${SCRIPT_DIR}/config-interactive"
# test-suite-manifest: support.sh syntax-and-terminal.sh input-validation.sh confirmation-and-state.sh signals-and-privacy.sh

source "$DOTFILES_TEST_SUITE_DIR/support.sh"
config_interactive_allocate_root
trap cleanup EXIT
config_interactive_initialize

source "$DOTFILES_TEST_SUITE_DIR/syntax-and-terminal.sh"
source "$DOTFILES_TEST_SUITE_DIR/input-validation.sh"
source "$DOTFILES_TEST_SUITE_DIR/confirmation-and-state.sh"
source "$DOTFILES_TEST_SUITE_DIR/signals-and-privacy.sh"

printf '%s config-interactive checks, %s failures\n' "$checks" "$failures"
[ "$failures" -eq 0 ]
