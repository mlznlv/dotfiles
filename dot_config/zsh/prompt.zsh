# Contextual native Zsh prompt: short path + explicit Git context.

autoload -Uz add-zsh-hook vcs_info
zmodload zsh/datetime 2>/dev/null || true
setopt PROMPT_SUBST

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '%F{green}+%f'
zstyle ':vcs_info:git:*' unstagedstr '%F{red}*%f'
zstyle ':vcs_info:git:*' formats '%F{yellow}%b%f%c%u'

typeset -g _DOTFILES_PROMPT_STARTED_AT=''
typeset -g _DOTFILES_PROMPT_CONTEXT=''
typeset -g _DOTFILES_PROMPT_GIT=''
typeset -g _DOTFILES_PROMPT_META=''

# Local shells do not need hostname noise. Remote shells do.
if [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]]; then
  _DOTFILES_PROMPT_CONTEXT='%F{magenta}%n@%m%f  '
fi

_dotfiles_prompt_preexec() {
  [[ -n "${EPOCHREALTIME:-}" ]] && _DOTFILES_PROMPT_STARTED_AT="$EPOCHREALTIME"
}

_dotfiles_prompt_precmd() {
  local exit_code="$?"
  local -i elapsed=0
  local duration=''
  local meta=''

  vcs_info

  if [[ -n "$vcs_info_msg_0_" ]]; then
    _DOTFILES_PROMPT_GIT="  %F{242}git:%f $vcs_info_msg_0_"
  else
    _DOTFILES_PROMPT_GIT=''
  fi

  if [[ -n "$_DOTFILES_PROMPT_STARTED_AT" && -n "${EPOCHREALTIME:-}" ]]; then
    elapsed=$(( EPOCHREALTIME - _DOTFILES_PROMPT_STARTED_AT ))
    (( elapsed >= 5 )) && duration="${elapsed}s"
  fi
  _DOTFILES_PROMPT_STARTED_AT=''

  if (( exit_code != 0 )); then
    meta="%F{red}✗ ${exit_code}%f"
  fi

  if [[ -n "$duration" ]]; then
    [[ -n "$meta" ]] && meta+='  '
    meta+="%F{242}${duration}%f"
  fi

  _DOTFILES_PROMPT_META="$meta"
}

add-zsh-hook preexec _dotfiles_prompt_preexec
add-zsh-hook precmd _dotfiles_prompt_precmd

# Keep the current location readable even in deep project trees: show only the
# last two path components. Git has an explicit label and its own color.
PROMPT='${_DOTFILES_PROMPT_CONTEXT}%B%F{cyan}%2~%f%b${_DOTFILES_PROMPT_GIT}
%F{green}❯%f '
RPROMPT='${_DOTFILES_PROMPT_META}'
