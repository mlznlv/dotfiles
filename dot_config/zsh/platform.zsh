case "$OSTYPE" in
  darwin*)
    DOTFILES_PLATFORM="macos"
    ;;
  linux*)
    DOTFILES_PLATFORM="linux"
    ;;
  *)
    DOTFILES_PLATFORM="unknown"
    ;;
esac

PLATFORM_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/platforms/${DOTFILES_PLATFORM}.zsh"

[[ -r "$PLATFORM_CONFIG" ]] && source "$PLATFORM_CONFIG"

unset PLATFORM_CONFIG DOTFILES_PLATFORM
