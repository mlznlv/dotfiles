# Starship owns prompt rendering. Preset and module selection are machine-local.

typeset -g DOTFILES_STARSHIP_DEFAULT_PRESET='plain-text-symbols'
typeset -g DOTFILES_STARSHIP_POLICY_REV='5'
typeset -g DOTFILES_STARSHIP_STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/starship"
typeset -g DOTFILES_STARSHIP_PRESET_FILE="$DOTFILES_STARSHIP_STATE_DIR/preset"
typeset -g DOTFILES_STARSHIP_MODULES_FILE="$DOTFILES_STARSHIP_STATE_DIR/modules"
typeset -g DOTFILES_STARSHIP_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/starship/presets"
typeset -ga DOTFILES_STARSHIP_POLICY_MODULES=(
  package
  aws
  gcloud
  azure
  kubernetes
  openstack
  docker_context
  localip
  nats
  pulumi
  terraform
  netns
  container
  singularity
)

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
  local requested="$1"
  local module

  for module in "${DOTFILES_STARSHIP_POLICY_MODULES[@]}"; do
    [[ "$requested" == "$module" ]] && return 0
  done
  return 1
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
  local module state signature=''

  for module in "${DOTFILES_STARSHIP_POLICY_MODULES[@]}"; do
    state='off'
    _dotfiles_starship_module_enabled "$module" && state='on'
    signature+="${module}-${state}_"
  done

  print -r -- "${signature%_}"
}

_dotfiles_starship_write_module_state() {
  local requested="$1"
  local requested_state="$2"
  local module state
  local temporary="$DOTFILES_STARSHIP_MODULES_FILE.tmp.$$"

  mkdir -p "$DOTFILES_STARSHIP_STATE_DIR"

  {
    for module in "${DOTFILES_STARSHIP_POLICY_MODULES[@]}"; do
      state='disabled'
      _dotfiles_starship_module_enabled "$module" && state='enabled'
      [[ "$module" == "$requested" ]] && state="$requested_state"
      print -r -- "$module=$state"
    done
  } > "$temporary" || {
    rm -f "$temporary"
    return 1
  }

  mv "$temporary" "$DOTFILES_STARSHIP_MODULES_FILE"
}

# Apply one visibility policy to every official preset. Exact module tables are
# edited in place. If a preset only contains nested module tables, the parent
# table is inserted before the first nested table so the generated TOML remains
# valid. The completed file is validated by Starship before it becomes active.
_dotfiles_starship_apply_policy() {
  local source="$1"
  local target="$2"
  local module disabled states=''

  for module in "${DOTFILES_STARSHIP_POLICY_MODULES[@]}"; do
    disabled='true'
    _dotfiles_starship_module_enabled "$module" && disabled='false'
    states+="$module=$disabled "
  done
  states="${states% }"

  awk -v states="$states" '
    BEGIN {
      count = split(states, pairs, " ")
      for (i = 1; i <= count; i++) {
        split(pairs[i], kv, "=")
        managed[kv[1]] = 1
        desired[kv[1]] = kv[2]
      }
    }

    {
      lines[NR] = $0
      compact = $0
      gsub(/[[:space:]]/, "", compact)
      for (name in managed) {
        if (compact == "[" name "]") exact_parent[name] = 1
      }
    }

    function flush_section() {
      if (section != "" && !disabled_written[section]) {
        print "disabled = " desired[section]
        disabled_written[section] = 1
      }
    }

    END {
      for (line_number = 1; line_number <= NR; line_number++) {
        line = lines[line_number]
        compact = line
        gsub(/[[:space:]]/, "", compact)

        if (compact ~ /^\[/) {
          flush_section()
          section = ""
          root = ""
          exact = 0

          for (name in managed) {
            if (compact == "[" name "]") {
              root = name
              exact = 1
              break
            }
            if (index(compact, "[" name ".") == 1) {
              root = name
              break
            }
          }

          if (root != "" && !exact && !exact_parent[root] && !parent_written[root]) {
            print "[" root "]"
            print "disabled = " desired[root]
            parent_written[root] = 1
            disabled_written[root] = 1
          }

          if (exact) {
            section = root
            parent_written[root] = 1
          }

          print line
          continue
        }

        if (section != "" && compact ~ /^disabled=/) {
          if (!disabled_written[section]) print "disabled = " desired[section]
          disabled_written[section] = 1
          continue
        }

        print line
      }

      flush_section()

      for (name in managed) {
        if (!exact_parent[name] && !parent_written[name]) {
          print ""
          print "[" name "]"
          print "disabled = " desired[name]
        }
      }
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

    if ! STARSHIP_CONFIG="$temporary" starship prompt >/dev/null 2>&1; then
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
  local state

  case "$action" in
    status)
      if (( $# > 1 )); then
        print -u2 -- 'Usage: prompt-module status'
        return 2
      fi
      for module in "${DOTFILES_STARSHIP_POLICY_MODULES[@]}"; do
        state='disabled'
        _dotfiles_starship_module_enabled "$module" && state='enabled'
        printf '%-15s %s\n' "$module" "$state"
      done
      return 0
      ;;
    reset)
      if (( $# > 1 )); then
        print -u2 -- 'Usage: prompt-module reset'
        return 2
      fi
      rm -f "$DOTFILES_STARSHIP_MODULES_FILE"
      print -r -- 'Starship prompt modules reset to portable defaults.'
      print -r -- 'Restart the shell to apply it: exec zsh -l'
      return 0
      ;;
    enable|disable)
      if (( $# != 2 )); then
        print -u2 -- 'Usage: prompt-module <enable|disable> <module>'
        return 2
      fi
      if ! _dotfiles_starship_supported_module "$module"; then
        print -u2 -- "Unsupported prompt module: $module"
        print -u2 -- "Supported modules: ${DOTFILES_STARSHIP_POLICY_MODULES[*]}"
        return 2
      fi
      [[ "$action" == 'enable' ]] && state='enabled' || state='disabled'
      ;;
    *)
      print -u2 -- 'Usage: prompt-module status | reset | <enable|disable> <module>'
      return 2
      ;;
  esac

  _dotfiles_starship_write_module_state "$module" "$state" || {
    print -u2 -- 'Could not update Starship module state.'
    return 1
  }

  print -r -- "Starship module '$module' is now $state."
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
