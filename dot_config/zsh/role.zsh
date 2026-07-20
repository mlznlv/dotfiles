ROLE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/role"

if [[ -r "$ROLE_FILE" ]]; then
  DOTFILES_ROLE="$(<"$ROLE_FILE")"
  ROLE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/roles/${DOTFILES_ROLE}.zsh"

  [[ -r "$ROLE_CONFIG" ]] && source "$ROLE_CONFIG"
fi

unset ROLE_FILE ROLE_CONFIG DOTFILES_ROLE
