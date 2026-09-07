#!/usr/bin/env bash

# Thin fixed loader for the sourceable maintainability architecture guard.

MAINTAINABILITY_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
MAINTAINABILITY_LOADER_DIR="${MAINTAINABILITY_SCRIPT_DIR}/maintainability"
# maintainability-module-manifest: common.sh file-sizes.sh production-shell.sh test-shell.sh

if [ ! -r "$MAINTAINABILITY_LOADER_DIR/common.sh" ]; then
    printf 'error: required maintainability component common is unavailable\n' >&2
    [ "${BASH_SOURCE[0]}" != "$0" ] && return 4
    exit 4
fi
source "$MAINTAINABILITY_LOADER_DIR/common.sh"
maintainability_load_status=$?
if [ "$maintainability_load_status" -ne 0 ]; then
    printf 'error: required maintainability component common could not be loaded\n' >&2
    [ "${BASH_SOURCE[0]}" != "$0" ] && return 4
    exit 4
fi

if [ ! -r "$MAINTAINABILITY_LOADER_DIR/file-sizes.sh" ]; then
    printf 'error: required maintainability component file-sizes is unavailable\n' >&2
    [ "${BASH_SOURCE[0]}" != "$0" ] && return 4
    exit 4
fi
source "$MAINTAINABILITY_LOADER_DIR/file-sizes.sh"
maintainability_load_status=$?
if [ "$maintainability_load_status" -ne 0 ]; then
    printf 'error: required maintainability component file-sizes could not be loaded\n' >&2
    [ "${BASH_SOURCE[0]}" != "$0" ] && return 4
    exit 4
fi

if [ ! -r "$MAINTAINABILITY_LOADER_DIR/production-shell.sh" ]; then
    printf 'error: required maintainability component production-shell is unavailable\n' >&2
    [ "${BASH_SOURCE[0]}" != "$0" ] && return 4
    exit 4
fi
source "$MAINTAINABILITY_LOADER_DIR/production-shell.sh"
maintainability_load_status=$?
if [ "$maintainability_load_status" -ne 0 ]; then
    printf 'error: required maintainability component production-shell could not be loaded\n' >&2
    [ "${BASH_SOURCE[0]}" != "$0" ] && return 4
    exit 4
fi

if [ ! -r "$MAINTAINABILITY_LOADER_DIR/test-shell.sh" ]; then
    printf 'error: required maintainability component test-shell is unavailable\n' >&2
    [ "${BASH_SOURCE[0]}" != "$0" ] && return 4
    exit 4
fi
source "$MAINTAINABILITY_LOADER_DIR/test-shell.sh"
maintainability_load_status=$?
if [ "$maintainability_load_status" -ne 0 ]; then
    printf 'error: required maintainability component test-shell could not be loaded\n' >&2
    [ "${BASH_SOURCE[0]}" != "$0" ] && return 4
    exit 4
fi
unset maintainability_load_status

maintainability_main() (
    set -u
    local script_dir repository_root failed=0

    script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
    repository_root=$(CDPATH= cd -- "${script_dir}/.." && pwd -P) || exit 1
    check_maintained_file_policy "$repository_root" || failed=1
    check_test_suite_layouts "$repository_root" || failed=1
    check_test_syntax "$repository_root" || failed=1
    check_test_execution_manifest "$repository_root" || failed=1
    check_production_modes "$repository_root" || failed=1
    check_production_syntax "$repository_root" || failed=1
    check_fixed_loaders "$repository_root" || failed=1
    check_catalog_program_loader "$repository_root" || failed=1
    check_maintainability_loader "$repository_root" || failed=1
    check_duplicate_function_definitions "$repository_root" || failed=1
    [ "$failed" -eq 0 ]
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    maintainability_main "$@"
fi
