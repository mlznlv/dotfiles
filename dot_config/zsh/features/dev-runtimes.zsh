# Development runtimes

# Node.js / NVM
export NVM_DIR="$HOME/.nvm"

[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# Python / pyenv
export PYENV_ROOT="$HOME/.pyenv"

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi
