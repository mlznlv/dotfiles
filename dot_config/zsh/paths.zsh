typeset -U path PATH

[[ -d "$HOME/.local/bin" ]] && path+=("$HOME/.local/bin")
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")

[[ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]] && \
  path+=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts")

[[ -d "/Applications/Sublime Text.app/Contents/SharedSupport/bin" ]] && \
  path=("/Applications/Sublime Text.app/Contents/SharedSupport/bin" $path)
