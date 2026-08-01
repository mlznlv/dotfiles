# Optional shell integrations.

MISE_ACTIVATE=''
if command -v mise >/dev/null 2>&1; then
  MISE_ACTIVATE="$(mise activate zsh 2>/dev/null)" || MISE_ACTIVATE=''
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  MISE_ACTIVATE="$("$HOME/.local/bin/mise" activate zsh 2>/dev/null)" || MISE_ACTIVATE=''
fi

if [[ -n "$MISE_ACTIVATE" ]]; then
  eval "$MISE_ACTIVATE"
elif command -v mise >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/mise" ]]; then
  print -u2 -- 'dotfiles: mise activation failed; run `mise doctor`.'
fi

unset MISE_ACTIVATE
