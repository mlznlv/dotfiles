# Starship owns prompt rendering. Preset selection is machine-local and does not
# modify the dotfiles repository.

 typeset -gr DOTFILES_STARSHIP_DEFAULT_PRESET='plain-text-symbols'
 typeset -gr DOTFILES_STARSHIP_STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/starship"
 typeset -gr DOTFILES_STARSHIP_PRESET_FILE="$DOTFILES_STARSHIP_STATE_DIR/preset"
 typeset -gr DOTFILES_STARSHIP_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/starship/presets"

_dotfiles_starship_normalize_preset() {
  case "$1" in
    plain-text)
      print -r -- 'plain-text-symbols'
      ;;
    *)
      print -r -- "$1"
      ;;
  esac
}

_dotfiles_starship_safe_preset_name() {
  case "$1" in
    ''|*[!A-Za-z0-9_-]*) return 1 ;;
    *) return 0 ;;
  esac
}

_dotfiles_starship_version() {
  local version
  version="$(starship --version 2>/dev/null)" || return 1
  version="${version%%$'\n'*}"
  version="${version#starship }"
  print -r -- "${version:-unknown}"
}

_dotfiles_starship_selected_preset() {
  local preset="${DOTFILES_STARSHIP_PRESET:-}"

  if [[ -z "$preset" && -r "$DOTFILES_STARSHIP_PRESET_FILE" ]]; then
    IFS= read -r preset < "$DOTFILES_STARSHIP_PRESET_FILE"
  fi

  [[ -n "$preset" ]] || preset="$DOTFILES_STARSHIP_DEFAULT_PRESET"
  _dotfiles_starship_normalize_preset "$preset"
}

_dotfiles_starship_config_for() {
  local preset version target
  preset="$(_dotfiles_starship_normalize_preset "$1")"
  _dotfiles_starship_safe_preset_name "$preset" || return 1

  version="$(_dotfiles_starship_version)" || version='unknown'
  target="$DOTFILES_STARSHIP_CACHE_DIR/$version/$preset.toml"

  if [[ ! -r "$target" ]]; then
    mkdir -p "${target:h}"
    if ! starship preset "$preset" -o "$target" >/dev/null; then
      rm -f "$target"
      return 1
    fi
  fi

  print -r -- "$target"
}

# Switch official Starship presets without creating chezmoi/git differences.
# `plain-text` is a convenience alias for Starship's `plain-text-symbols` preset.
prompt-preset() {
  local requested="${1:-}"
  local preset target

  if ! command -v starship >/dev/null 2>&1; then
    print -u2 -- 'starship is not installed.'
    return 1
  fi

  if (( $# > 1 )); then
    print -u2 -- 'Usage: prompt-preset [<preset>|default]'
    return 2
  fi

  if [[ -z "$requested" ]]; then
    print -r -- "Current preset: $(_dotfiles_starship_selected_preset)"
    print -r -- "Default preset: $DOTFILES_STARSHIP_DEFAULT_PRESET"
    print -r -- 'Usage: prompt-preset <preset> | prompt-preset default'
    return 0
  fi

  case "$requested" in
    default|reset)
      rm -f "$DOTFILES_STARSHIP_PRESET_FILE"
      preset="$DOTFILES_STARSHIP_DEFAULT_PRESET"
      ;;
    *)
      preset="$(_dotfiles_starship_normalize_preset "$requested")"
      if ! _dotfiles_starship_safe_preset_name "$preset"; then
        print -u2 -- "Invalid preset name: $requested"
        return 2
      fi

      target="$(_dotfiles_starship_config_for "$preset")" || {
        print -u2 -- "Unknown or unavailable Starship preset: $requested"
        return 1
      }

      mkdir -p "$DOTFILES_STARSHIP_STATE_DIR"
      print -r -- "$preset" > "$DOTFILES_STARSHIP_PRESET_FILE"
      ;;
  esac

  print -r -- "Starship preset selected: $preset"
  print -r -- 'Restart the shell to apply it: exec zsh -l'
}

if command -v starship >/dev/null 2>&1; then
  _DOTFILES_STARSHIP_PRESET="$(_dotfiles_starship_selected_preset)"

  if ! _dotfiles_starship_safe_preset_name "$_DOTFILES_STARSHIP_PRESET"; then
    print -u2 -- "Ignoring invalid Starship preset name: $_DOTFILES_STARSHIP_PRESET"
    _DOTFILES_STARSHIP_PRESET="$DOTFILES_STARSHIP_DEFAULT_PRESET"
  fi

  if ! STARSHIP_CONFIG="$(_dotfiles_starship_config_for "$_DOTFILES_STARSHIP_PRESET")"; then
    print -u2 -- "Could not load Starship preset '$_DOTFILES_STARSHIP_PRESET'; falling back to '$DOTFILES_STARSHIP_DEFAULT_PRESET'."
    _DOTFILES_STARSHIP_PRESET="$DOTFILES_STARSHIP_DEFAULT_PRESET"
    STARSHIP_CONFIG="$(_dotfiles_starship_config_for "$_DOTFILES_STARSHIP_PRESET")"
  fi

  export STARSHIP_CONFIG
  eval "$(starship init zsh)"
  unset _DOTFILES_STARSHIP_PRESET
else
  # Keep a usable prompt on machines where Starship has not been provisioned yet.
  PROMPT='[%n@%m %1~] %# '
fi
