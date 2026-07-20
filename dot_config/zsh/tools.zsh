# Shared shell UX tools and optional development runtime integrations.

# Legacy runtime managers remain supported during migration. Projects can move
# to mise incrementally without breaking the existing workstation setup.
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

export PYENV_ROOT="$HOME/.pyenv"
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
fi

# fzf. Prefer the modern generated Zsh integration, but preserve compatibility
# with older installations that still expose ~/.fzf.zsh.
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

# zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# mise is activated last so project-local mise configuration has final say over
# PATH when a project opts into mise. Machines without mise keep working.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
fi
