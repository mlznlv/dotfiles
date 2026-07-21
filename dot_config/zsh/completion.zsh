# Native Zsh completion subsystem. This loads early by design.

# Docker Desktop exposes Zsh completions here on macOS. Add this before compinit.
if [[ -d "$HOME/.docker/completions" ]]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

ZSH_COMPLETION_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$ZSH_COMPLETION_CACHE"

# Keep completion dumps isolated across Zsh upgrades.
autoload -Uz compinit
compinit -d "$ZSH_COMPLETION_CACHE/zcompdump-$ZSH_VERSION"

# Predictable completion: Tab completes/selects, Shift-Tab moves backward.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

bindkey -e
bindkey '^[[Z' reverse-menu-complete

# Keep arrow keys as immediate command-history navigation.
bindkey '^[OA' up-line-or-history
bindkey '^[[A' up-line-or-history
bindkey '^[OB' down-line-or-history
bindkey '^[[B' down-line-or-history

unset ZSH_COMPLETION_CACHE
