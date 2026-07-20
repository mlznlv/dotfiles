# Interactive shell UX loaded after completion and runtime integrations.

# Fuzzy search and navigation.
if command -v fzf >/dev/null 2>&1; then
  FZF_ZSH_INIT="$(fzf --zsh 2>/dev/null || true)"
  if [[ -n "$FZF_ZSH_INIT" ]]; then
    eval "$FZF_ZSH_INIT"
  elif [[ -r "$HOME/.fzf.zsh" ]]; then
    source "$HOME/.fzf.zsh"
  fi
  unset FZF_ZSH_INIT
elif [[ -r "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh"
fi

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# Interactive feedback plugins.
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

_source_zsh_plugin \
  "$ZSH_PLUGIN_HOME/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "${BREW_SHARE:+$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh}"

# Keep syntax highlighting last so it sees all ZLE widgets/hooks.
_source_zsh_plugin \
  "$ZSH_PLUGIN_HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "${BREW_SHARE:+$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh}"

unset -f _source_zsh_plugin
unset ZSH_PLUGIN_HOME BREW_SHARE
