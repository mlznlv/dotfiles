# Shared completion configuration.

# Docker Desktop exposes Zsh completions here on macOS. Keep this capability-based
# so the same shell config remains valid on hosts without Docker Desktop.
if [[ -d "$HOME/.docker/completions" ]]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi
