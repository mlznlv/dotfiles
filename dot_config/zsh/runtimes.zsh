# Runtime/version-manager integrations.

# Existing workstation compatibility. New machines do not need NVM: mise can
# manage Node and read .nvmrc through the global mise settings.
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# Existing workstation compatibility for Python projects still using pyenv.
export PYENV_ROOT="$HOME/.pyenv"
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
fi

# Target runtime manager. Load last so mise-managed project versions win when
# a project opts into mise (or an enabled idiomatic version file such as .nvmrc).
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
fi
