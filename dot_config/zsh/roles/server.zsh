# Server-specific configuration

# Development runtimes
DEV_RUNTIMES="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/features/dev-runtimes.zsh"
[[ -r "$DEV_RUNTIMES" ]] && source "$DEV_RUNTIMES"
unset DEV_RUNTIMES
