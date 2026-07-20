typeset -U path PATH

[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")
