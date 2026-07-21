# Starship owns prompt rendering. Preset and module selection are machine-local.

typeset -gr DOTFILES_STARSHIP_DEFAULT_PRESET='plain-text-symbols'
typeset -gr DOTFILES_STARSHIP_POLICY_REV='3'
typeset -gr DOTFILES_STARSHIP_STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/starship"
typeset -gr DOTFILES_STARSHIP_PRESET_FILE="$DOTFILES_STARSHIP_STATE_DIR/preset"
typeset -gr DOTFILES_STARSHIP_MODULES_FILE="$DOTFILES_STARSHIP_STATE_DIR/modules"
typeset -gr DOTFILES_STARSHIP_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/starship/presets"

_dotfiles_starship_native_prompt() {
  unset STARSHIP_CONFIG
  PROMPT='[%n@%m %1~] %# '
  RPROMPT=''
}

_dotfiles_starship_normalize_preset() {
  case "$1" in
    plain-text) print -r -- 'plain-text-symbols' ;;
    *) print -r -- "$1" ;;
  esac
}

_dotfiles_starship_safe_preset_name() {
  case "$1" in
    ''|*[!A-Za-z0-9_-]*) return 1 ;;
    *) return 0 ;;
  esac
}

_dotfiles_starship_supported_module() {
  case "$1" in
    package|aws|gcloud) return 0 ;;
    *) return 1 ;;
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

_dotfiles_starship_module_enabled() {
  local requested="$1"
  local name state

  [[ -r "$DOTFILES_STARSHIP_MODULES_FILE" ]] || return 1

  while IFS='=' read -r name state; do
    [[ "$name" == "$requested" ]] || continue
    [[ "$state" == 'enabled' ]]
    return
  done < "$DOTFILES_STARSHIP_MODULES_FILE"

  return 1
}

_dotfiles_starship_module_signature() {
  local module signature=''

  for module in package aws gcloud; do
    if _dotfiles_starship_module_enabled "$module"; then
      signature+="${module}-on_"
    else
      signature+="${module}-off_"
    fi
  done

  print -r -- "${signature%_}"
}

_dotfiles_starship_write_module_state() {
  local package_state="$1"
  local aws_state="$2"
  local gcloud_state="$3"
  local temporary="$DOTFILES_STARSHIP_MODULES_FILE.tmp.$$"

  mkdir -p "$DOTFILES_STARSHIP_STATE_DIR"

  {
    print -r -- "package=$package_state"
    print -r -- "aws=$aws_state"
    print -r -- "gcloud=$gcloud_state"
  } > "$temporary" || {
    rm -f "$temporary"
    return 1
  }

  mv "$temporary" "$DOTFILES_STARSHIP_MODULES_FILE"
}

# Apply the same machine-local visibility policy to every official preset.
_dotfiles_starship_apply_policy() {
  local source="$1"
  local target="$2"
  local package_disabled='true'
  local aws_disabled='true'
  local gcloud_disabled='true'

  _dotfiles_starship_module_enabled package && package_disabled='false'
  _dotfiles_starship_module_enabled aws && aws_disabled='false'
  _dotfiles_starship_module_enabled gcloud && gcloud_disabled='false'

  awk \
    -v package_disabled="$package_disabled" \
    -v aws_disabled="$aws_disabled" \
    -v gcloud_disabled="$gcloud_disabled" '
    BEGIN {
      desired["package"] = package_disabled
      desired["aws"] = aws_disabled
      desired["gcloud"] = gcloud_disabled
    }

    function flush_section() {
      if (section != "" && !disabled_written[section]) {
        print "disabled = " desired[section]
        disabled_written[section] = 1
      }
    }

    function append_section(name) {
      if (!seen[name]) {
        print ""
        print "[" name "]"
        print "disabled = " desired[name]
      }
    }

    {
      line = $0

      if (line ~ /^[[:space:]]*\[/) {
        flush_section()
        section = ""
        compact = line
        gsub(/[[:space:]]/, "", compact)

        if (compact == "[package]") section = "package"
        else if (compact == "[aws]") section = "aws"
        else if (compact == "[gcloud]") section = "gcloud"

        if (section != "") seen[section] = 1
        print line
        next
      }

      if (section != "" && line ~ /^[[:space:]]*disabled[[:space:]]*=/) {
        if (!disabled_written[section]) print "disabled = " desired[section]
        disabled_written[section] = 1
        next
      }

      print line
    }

    END {
      flush_section()
      append_section("package")
      append_section("aws")
      append_section("gcloud")
    }
  ' "$source" > "$target"
}

_dotfiles_starship_config_for() {
  local preset version signature target raw temporary
  preset="$(_dotfiles_starship_normalize_preset "$1")"
  _dotfiles_starship_safe_preset_name "$preset" || return 1

  version="$(_dotfiles_starship_version)" || return 1
  signature="$(_dotfiles_starship_module_signature)"
  target="$DOTFILES_STARSHIP_CACHE_DIR/$version/policy-v$DOTFILES_STARSHIP_POLICY_REV/$signature/$preset.toml"

  if [[ ! -r "$target" ]]; then
    mkdir -p "${target:h}"
    raw="${target}.preset.$$"
    temporary="${target}.tmp.$$"

    if ! starship preset "$preset" -o "$raw" >/dev/null 2>&1; then
      rm -f "$raw" "$temporary"
      return 1
    fi

    if ! _dotfiles_starship_apply_policy "$raw" "$temporary"; then
      rm -f "$raw" "$temporary"
      return 1
    fi

    mv "$temporary" "$target" || {
      rm -f "$raw" "$temporary"
      return 1
    }
    rm -f "$raw"
  fi

  [[ -r "$target" ]] || return 1
  print -r -- "$target"
}

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
      preset="$DOTFILES_STARSHIP_DEFAULT_PRESET"
      target="$(_dotfiles_starship_config_for "$preset")" || {
        print -u2 -- "Default Starship preset is unavailable: $preset"
        return 1
      }
      rm -f "$DOTFILES_STARSHIP_PRESET_FILE"
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

prompt-module() {
  local action="${1:-status}"
  local module="${2:-}"
  local package_state='disabled'
  local aws_state='disabled'
  local gcloud_state='disabled'
  local next_state

  _dotfiles_starship_module_enabled package && package_state='enabled'
  _dotfiles_starship_module_enabled aws && aws_state='enabled'
  _dotfiles_starship_module_enabled gcloud && gcloud_state='enabled'

  case "$action" in
    status)
      if (( $# > 1 )); then
        print -u2 -- 'Usage: prompt-module status'
        return 2
      fi
      print -r -- "package  $package_state"
      print -r -- "aws      $aws_state"
      print -r -- "gcloud   $gcloud_state"
      return 0
      ;;
    reset)
      if (( $# > 1 )); then
        print -u2 -- 'Usage: prompt-module reset'
        return 2
      fi
      rm -f "$DOTFILES_STARSHIP_MODULES_FILE"
      print -r -- 'Starship prompt modules reset to defaults: package/aws/gcloud disabled.'
      print -r -- 'Restart the shell to apply it: exec zsh -l'
      return 0
      ;;
    enable|disable)
      if (( $# != 2 )); then
        print -u2 -- 'Usage: prompt-module <enable|disable> <package|aws|gcloud>'
        return 2
      fi
      if ! _dotfiles_starship_supported_module "$module"; then
        print -u2 -- "Unsupported prompt module: $module"
        print -u2 -- 'Supported modules: package, aws, gcloud'
        return 2
      fi
      [[ "$action" == 'enable' ]] && next_state='enabled' || next_state='disabled'
      ;;
    *)
      print -u2 -- 'Usage: prompt-module status | reset | <enable|disable> <package|aws|gcloud>'
      return 2
      ;;
  esac

  case "$module" in
    package) package_state="$next_state" ;;
    aws) aws_state="$next_state" ;;
    gcloud) gcloud_state="$next_state" ;;
  esac

  _dotfiles_starship_write_module_state "$package_state" "$aws_state" "$gcloud_state" || {
    print -u2 -- 'Could not update Starship module state.'
    return 1
  }

  print -r -- "Starship module '$module' is now $next_state."
  print -r -- 'Restart the shell to apply it: exec zsh -l'
}

_dotfiles_starship_init() {
  local preset config init_script

  if ! command -v starship >/dev/null 2>&1; then
    _dotfiles_starship_native_prompt
    return
  fi

  preset="$(_dotfiles_starship_selected_preset)"
  if ! _dotfiles_starship_safe_preset_name "$preset"; then
    print -u2 -- "dotfiles: ignoring invalid Starship preset name: $preset"
    preset="$DOTFILES_STARSHIP_DEFAULT_PRESET"
  fi

  if ! config="$(_dotfiles_starship_config_for "$preset")"; then
    if [[ "$preset" != "$DOTFILES_STARSHIP_DEFAULT_PRESET" ]]; then
      print -u2 -- "dotfiles: could not load Starship preset '$preset'; trying '$DOTFILES_STARSHIP_DEFAULT_PRESET'."
      preset="$DOTFILES_STARSHIP_DEFAULT_PRESET"
      config="$(_dotfiles_starship_config_for "$preset")" || config=''
    else
      config=''
    fi
  fi

  if [[ -z "$config" || ! -r "$config" ]]; then
    print -u2 -- 'dotfiles: Starship config generation failed; using the native Zsh prompt.'
    _dotfiles_starship_native_prompt
    return
  fi

  export STARSHIP_CONFIG="$config"
  init_script="$(starship init zsh 2>/dev/null)" || init_script=''
  if [[ -z "$init_script" ]] || ! eval "$init_script"; then
    print -u2 -- 'dotfiles: Starship initialization failed; using the native Zsh prompt.'
    _dotfiles_starship_native_prompt
  fi
}

_dotfiles_starship_init
unset -f _dotfiles_starship_init
