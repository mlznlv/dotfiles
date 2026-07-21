#!/usr/bin/env bash
set -euo pipefail

# Remove files from the legacy layered Zsh design only when their content still
# exactly matches a known Git blob from the old managed state.
ZSH_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

remove_legacy_zsh_file() {
  local relative_path="$1"
  local expected_blob="$2"
  local target="$ZSH_CONFIG_HOME/$relative_path"
  local actual_blob

  [[ -f "$target" ]] || return 0
  actual_blob="$(git hash-object -- "$target" 2>/dev/null)" || return 0
  [[ "$actual_blob" == "$expected_blob" ]] || return 0

  printf 'Removing obsolete managed Zsh file: %s\n' "$target"
  rm -f -- "$target"
}

remove_legacy_zsh_file "features/dev-runtimes.zsh" "8d494c68665ae897443c3ab79d00496d2ca94856"
remove_legacy_zsh_file "platform.zsh" "978ce53b6a36d8be2d1bba1d7842abff87e270be"
remove_legacy_zsh_file "platforms/linux.profile.zsh" "80a62c079b9f58f9fa15d3cfaa9853bf960a0122"
remove_legacy_zsh_file "platforms/linux.zsh" "fb22d7245e1b6974badbeb42a0fa7d7f683dfd96"
remove_legacy_zsh_file "platforms/macos.profile.zsh" "6dfb02526cde08d0598258b868e499bddfaf7606"
remove_legacy_zsh_file "platforms/macos.zsh" "f4e2d4403b26837acbe2efea1cc56d86920f4dbf"
remove_legacy_zsh_file "plugins.zsh" "b31ef293b5333a3e1e1d76c97e1c36c36fcc86ee"
remove_legacy_zsh_file "role.zsh" "40325c1d133643f1dc9d2e337deaac8c546a34d5"
remove_legacy_zsh_file "roles/client.zsh" "ecc55769b451c755cc5f2a9a687c80f73e66fea8"
remove_legacy_zsh_file "roles/server.zsh" "8da9200e43c83ec6592e3c3926876bde034eccb5"
remove_legacy_zsh_file "roles/workstation.zsh" "8910875dc18f0c7edb0954e45e847c3bb90c2284"
remove_legacy_zsh_file "tools.zsh" "7701aad0ca8afae813bb9d84357e7505f4542e80"

rmdir \
  "$ZSH_CONFIG_HOME/features" \
  "$ZSH_CONFIG_HOME/platforms" \
  "$ZSH_CONFIG_HOME/roles" \
  2>/dev/null || true

# zsh-autocomplete was previously managed as a Git checkout. Remove it only when
# the origin is the known upstream and the worktree can be verified as clean.
LEGACY_AUTOCOMPLETE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zsh-autocomplete"
if [[ -d "$LEGACY_AUTOCOMPLETE_DIR/.git" ]]; then
  LEGACY_AUTOCOMPLETE_ORIGIN="$(git -C "$LEGACY_AUTOCOMPLETE_DIR" config --get remote.origin.url 2>/dev/null || true)"
  case "$LEGACY_AUTOCOMPLETE_ORIGIN" in
    https://github.com/marlonrichert/zsh-autocomplete|https://github.com/marlonrichert/zsh-autocomplete.git|git@github.com:marlonrichert/zsh-autocomplete.git|ssh://git@github.com/marlonrichert/zsh-autocomplete.git)
      if LEGACY_AUTOCOMPLETE_STATUS="$(git -C "$LEGACY_AUTOCOMPLETE_DIR" status --porcelain 2>/dev/null)"; then
        if [[ -z "$LEGACY_AUTOCOMPLETE_STATUS" ]]; then
          printf 'Removing obsolete zsh-autocomplete checkout: %s\n' "$LEGACY_AUTOCOMPLETE_DIR"
          rm -rf -- "$LEGACY_AUTOCOMPLETE_DIR"
        else
          printf 'Leaving obsolete zsh-autocomplete checkout with local changes: %s\n' "$LEGACY_AUTOCOMPLETE_DIR" >&2
        fi
      else
        printf 'Leaving obsolete zsh-autocomplete checkout with unverifiable Git state: %s\n' "$LEGACY_AUTOCOMPLETE_DIR" >&2
      fi
      ;;
  esac
fi
