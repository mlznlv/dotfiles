# Interactive shell behavior loaded after completion and tool integrations.

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

# Must remain last so syntax highlighting observes all ZLE widgets/hooks.
_source_zsh_plugin \
  "$ZSH_PLUGIN_HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "${BREW_SHARE:+$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh}"

unset -f _source_zsh_plugin
unset ZSH_PLUGIN_HOME BREW_SHARE
