# Homebrew Zsh plugins
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"

  [[ -r "$BREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] && \
    source "$BREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

  [[ -r "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

  # Must stay last
  [[ -r "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

  unset BREW_PREFIX
fi
