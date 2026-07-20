typeset -U path PATH

# User-local executables.
[[ -d "$HOME/.local/bin" ]] && path+=("$HOME/.local/bin")

# Optional local Docker Desktop/CLI installation.
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")
