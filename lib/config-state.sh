# Fixed source-only local-selection state facade. Dependency order is schema,
# storage, reader, lock, then writer. This path preserves the existing API.

DOTFILES_CONFIG_STATE_LOADER_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || {
    printf 'error: local selection state component root is unavailable\n' >&2
    return 4
}

if [ ! -r "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/schema.sh" ]; then
    printf 'error: required local selection state component schema is unavailable\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
fi
# shellcheck source=config-state/schema.sh
source "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/schema.sh" || {
    printf 'error: required local selection state component schema failed to load\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
}

if [ ! -r "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/storage.sh" ]; then
    printf 'error: required local selection state component storage is unavailable\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
fi
# shellcheck source=config-state/storage.sh
source "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/storage.sh" || {
    printf 'error: required local selection state component storage failed to load\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
}

if [ ! -r "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/reader.sh" ]; then
    printf 'error: required local selection state component reader is unavailable\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
fi
# shellcheck source=config-state/reader.sh
source "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/reader.sh" || {
    printf 'error: required local selection state component reader failed to load\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
}

if [ ! -r "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/lock.sh" ]; then
    printf 'error: required local selection state component lock is unavailable\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
fi
# shellcheck source=config-state/lock.sh
source "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/lock.sh" || {
    printf 'error: required local selection state component lock failed to load\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
}

if [ ! -r "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/writer.sh" ]; then
    printf 'error: required local selection state component writer is unavailable\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
fi
# shellcheck source=config-state/writer.sh
source "$DOTFILES_CONFIG_STATE_LOADER_DIR/config-state/writer.sh" || {
    printf 'error: required local selection state component writer failed to load\n' >&2
    unset DOTFILES_CONFIG_STATE_LOADER_DIR
    return 4
}

unset DOTFILES_CONFIG_STATE_LOADER_DIR
