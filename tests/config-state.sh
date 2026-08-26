#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)
DOTFILES_TEST_SUITE_DIR="${SCRIPT_DIR}/config-state"
# test-suite-manifest: support.sh cli-and-persistence.sh path-and-state-validation.sh writer-failures-and-drift.sh concurrency-signals-and-privacy.sh

source "$DOTFILES_TEST_SUITE_DIR/support.sh"
config_state_allocate_root
trap cleanup EXIT
config_state_initialize

source "$DOTFILES_TEST_SUITE_DIR/cli-and-persistence.sh"
source "$DOTFILES_TEST_SUITE_DIR/path-and-state-validation.sh"
source "$DOTFILES_TEST_SUITE_DIR/writer-failures-and-drift.sh"
source "$DOTFILES_TEST_SUITE_DIR/concurrency-signals-and-privacy.sh"

printf '%s config-state checks, %s failures\n' "$checks" "$failures"
[ "$failures" -eq 0 ]
