typeset -U path PATH

# Preserve the previous precedence for user-managed tools while keeping every
# entry capability-based so the same config works on clean or remote hosts.
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d "$HOME/.antigravity/antigravity/bin" ]] && path=("$HOME/.antigravity/antigravity/bin" $path)
[[ -d "$HOME/.pyenv/bin" ]] && path=("$HOME/.pyenv/bin" $path)

# Docker Desktop/CLI historically lived after the system/user PATH entries.
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")
