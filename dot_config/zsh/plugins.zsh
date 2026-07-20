# Shared late-loaded Zsh plugins.
# zsh-autocomplete is initialized earlier from completion.zsh because it owns
# compinit and must be loaded before integrations that may call compdef.

ZSH_PLUGIN_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

_source_zsh_plugin() {
  local candidate

  for candidate in "$@"; do
    [[ -n "$candidate" && -r "$candidate" ]] || continue
    source "$candidate"
    return 0
  done

  return 1
}

BREW_SHARE=""
if command -v brew >/dev/null 2>&1; then
  BREW_SHARE="$(brew --prefix)/share"
fi

# Autosuggestions.
_source_zsh_plugin \
  "$ZSH_PLUGIN_HOME/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "${BREW_SHARE:+$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh}"

# Must remain the final plugin sourced so it observes all ZLE widgets/hooks.
_source_zsh_plugin \
  "$ZSH_PLUGIN_HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "${BREW_SHARE:+$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh}"

unset -f _source_zsh_plugin
unset ZSH_PLUGIN_HOME BREW_SHARE
