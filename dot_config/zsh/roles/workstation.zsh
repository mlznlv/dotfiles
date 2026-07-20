# Workstation-specific configuration

# Docker CLI
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")

# Docker completion
[[ -d "$HOME/.docker/completions" ]] && \
  fpath=("$HOME/.docker/completions" $fpath)
