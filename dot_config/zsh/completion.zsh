# Zsh completion subsystem. This loads early by design.

# Docker Desktop exposes Zsh completions here on macOS. Add this before
# zsh-autocomplete initializes Zsh's completion system.
if [[ -d "$HOME/.docker/completions" ]]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

# zsh-autocomplete owns compinit and must be sourced before integrations that
# may register completions with compdef.
ZSH_PLUGIN_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
AUTOCOMPLETE_PLUGIN="$ZSH_PLUGIN_HOME/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

if [[ -r "$AUTOCOMPLETE_PLUGIN" ]]; then
  source "$AUTOCOMPLETE_PLUGIN"
elif command -v brew >/dev/null 2>&1; then
  BREW_AUTOCOMPLETE="$(brew --prefix)/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
  [[ -r "$BREW_AUTOCOMPLETE" ]] && source "$BREW_AUTOCOMPLETE"
  unset BREW_AUTOCOMPLETE
fi

# zsh-autocomplete maps the arrow keys to its completion/history menus by
# default. Keep terminal-native behavior instead: Up/Down navigate command
# history immediately. Ctrl-R remains available for interactive history search.
bindkey '^[OA'  .up-line-or-history
bindkey '^[[A'  .up-line-or-history
bindkey '^[OB'  .down-line-or-history
bindkey '^[[B'  .down-line-or-history

unset AUTOCOMPLETE_PLUGIN ZSH_PLUGIN_HOME