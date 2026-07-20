# Contextual native Zsh prompt: path + Git, with remote context only over SSH.

autoload -Uz add-zsh-hook vcs_info
zmodload zsh/datetime 2>/dev/null || true
setopt PROMPT_SUBST

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' formats '%b%c%u'

typeset -g _DOTFILES_PROMPT_STARTED_AT=''
typeset -g _DOTFILES_PROMPT_CONTEXT=''
typeset -g _DOTFILES_PROMPT_GIT=''
typeset -g _DOTFILES_PROMPT_META=''

if [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]]; then
  _DOTFILES_PROMPT_CONTEXT='%n@%m  '
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
    _DOTFILES_PROMPT_GIT="  $vcs_info_msg_0_"
  else
    _DOTFILES_PROMPT_GIT=''
  fi

  if [[ -n "$_DOTFILES_PROMPT_STARTED_AT" && -n "${EPOCHREALTIME:-}" ]]; then
    elapsed=$(( EPOCHREALTIME - _DOTFILES_PROMPT_STARTED_AT ))
    (( elapsed >= 5 )) && duration="${elapsed}s"
  fi
  _DOTFILES_PROMPT_STARTED_AT=''

  if (( exit_code != 0 )); then
    meta="✗ ${exit_code}"
  fi

  if [[ -n "$duration" ]]; then
    [[ -n "$meta" ]] && meta+=' · '
    meta+="$duration"
  fi

  _DOTFILES_PROMPT_META="$meta"
}

add-zsh-hook preexec _dotfiles_prompt_preexec
add-zsh-hook precmd _dotfiles_prompt_precmd

PROMPT='${_DOTFILES_PROMPT_CONTEXT}%~${_DOTFILES_PROMPT_GIT}
❯ '
RPROMPT='${_DOTFILES_PROMPT_META}'