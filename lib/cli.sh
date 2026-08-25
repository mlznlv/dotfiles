# Fixed source-only CLI facade. Dependency order is common, catalog,
# selection, config commands, then execution commands.

DOTFILES_CLI_LOADER_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || {
    printf 'error: CLI component root is unavailable\n' >&2
    return 4
}

if [ ! -r "$DOTFILES_CLI_LOADER_DIR/cli/common.sh" ]; then
    printf 'error: required CLI component common is unavailable\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
fi
# shellcheck source=cli/common.sh
source "$DOTFILES_CLI_LOADER_DIR/cli/common.sh" || {
    printf 'error: required CLI component common failed to load\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
}

if [ ! -r "$DOTFILES_CLI_LOADER_DIR/cli/catalog.sh" ]; then
    printf 'error: required CLI component catalog is unavailable\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
fi
# shellcheck source=cli/catalog.sh
source "$DOTFILES_CLI_LOADER_DIR/cli/catalog.sh" || {
    printf 'error: required CLI component catalog failed to load\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
}

if [ ! -r "$DOTFILES_CLI_LOADER_DIR/cli/selection.sh" ]; then
    printf 'error: required CLI component selection is unavailable\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
fi
# shellcheck source=cli/selection.sh
source "$DOTFILES_CLI_LOADER_DIR/cli/selection.sh" || {
    printf 'error: required CLI component selection failed to load\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
}

if [ ! -r "$DOTFILES_CLI_LOADER_DIR/cli/config-commands.sh" ]; then
    printf 'error: required CLI component config-commands is unavailable\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
fi
# shellcheck source=cli/config-commands.sh
source "$DOTFILES_CLI_LOADER_DIR/cli/config-commands.sh" || {
    printf 'error: required CLI component config-commands failed to load\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
}

if [ ! -r "$DOTFILES_CLI_LOADER_DIR/cli/execution-commands.sh" ]; then
    printf 'error: required CLI component execution-commands is unavailable\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
fi
# shellcheck source=cli/execution-commands.sh
source "$DOTFILES_CLI_LOADER_DIR/cli/execution-commands.sh" || {
    printf 'error: required CLI component execution-commands failed to load\n' >&2
    unset DOTFILES_CLI_LOADER_DIR
    return 4
}

unset DOTFILES_CLI_LOADER_DIR
