# Workstation-specific configuration

# Docker CLI
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")

# Docker completion
[[ -d "$HOME/.docker/completions" ]] && \
  fpath=("$HOME/.docker/completions" $fpath)

# Development runtimes
DEV_RUNTIMES="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/features/dev-runtimes.zsh"
[[ -r "$DEV_RUNTIMES" ]] && source "$DEV_RUNTIMES"
unset DEV_RUNTIMES
