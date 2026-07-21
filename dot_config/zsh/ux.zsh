# Interactive shell UX loaded after completion and runtime integrations.

_source_first_readable() {
  local candidate

  for candidate in "$@"; do
    [[ -n "$candidate" && -r "$candidate" ]] || continue
    source "$candidate"
    return 0
  done

  return 1
}

# Prefer fzf's self-contained Zsh init on recent versions. Debian/Ubuntu may ship
# an older fzf, so fall back to the packaged key-binding script when necessary.
if command -v fzf >/dev/null 2>&1; then
  FZF_ZSH_INIT="$(fzf --zsh 2>/dev/null || true)"
  if [[ -n "$FZF_ZSH_INIT" ]]; then
    eval "$FZF_ZSH_INIT"
  else
    _source_first_readable \
      "$HOME/.fzf.zsh" \
      "/usr/share/doc/fzf/examples/key-bindings.zsh" \
      "/usr/share/fzf/key-bindings.zsh" \
      "/usr/share/fzf/shell/key-bindings.zsh" \
      >/dev/null 2>&1 || true
  fi
  unset FZF_ZSH_INIT
fi

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# Zsh plugins are owned only by mise bootstrap.repos.
ZSH_PLUGIN_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

if ! _source_first_readable \
  "$ZSH_PLUGIN_HOME/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
  print -u2 -- "dotfiles: zsh-autosuggestions is missing; rerun bootstrap for this machine profile."
fi

# Keep syntax highlighting after all other ZLE integrations.
if ! _source_first_readable \
  "$ZSH_PLUGIN_HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; then
  print -u2 -- "dotfiles: zsh-syntax-highlighting is missing; rerun bootstrap for this machine profile."
fi

unset -f _source_first_readable
unset ZSH_PLUGIN_HOME
