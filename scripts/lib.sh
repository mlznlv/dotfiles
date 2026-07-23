# Shared helpers for repository entrypoint scripts.

dotfiles_detect_platform() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' 'macos' ;;
    Linux) printf '%s\n' 'linux' ;;
    *) return 1 ;;
  esac
}

dotfiles_print_profile_usage() {
  local command_name="$1"

  printf 'Usage: %s <profile>\n' "$command_name"
  printf '%s\n' '  macOS 13+: base, local-dev, remote-client'
  printf '%s\n' '  Linux (Ubuntu/Debian): base, dev-host'
}

dotfiles_validate_profile() {
  local platform="$1"
  local profile="$2"

  case "$platform/$profile" in
    macos/base|macos/local-dev|macos/remote-client|linux/base|linux/dev-host)
      return 0
      ;;
    *)
      printf 'Unsupported platform/profile combination: %s/%s\n' "$platform" "$profile" >&2
      return 1
      ;;
  esac
}

dotfiles_require_supported_os() {
  local platform="$1"
  local version major

  case "$platform" in
    macos)
      version="$(sw_vers -productVersion 2>/dev/null || true)"
      major="${version%%.*}"
      case "$major" in
        ''|*[!0-9]*)
          printf 'Could not determine the macOS version.\n' >&2
          return 1
          ;;
      esac
      if (( major < 13 )); then
        printf 'Unsupported macOS version: %s (macOS 13+ required).\n' "$version" >&2
        return 1
      fi
      ;;
    linux)
      if ! command -v apt-get >/dev/null 2>&1; then
        printf '%s\n' 'Unsupported Linux distribution: apt-get is required.' >&2
        printf '%s\n' 'This repository currently supports Ubuntu/Debian Linux hosts.' >&2
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

dotfiles_find_executable() {
  local name="$1"
  local resolved

  resolved="$(command -v "$name" 2>/dev/null || true)"
  if [[ -n "$resolved" && -x "$resolved" ]]; then
    printf '%s\n' "$resolved"
    return 0
  fi

  if [[ -x "$HOME/.local/bin/$name" ]]; then
    printf '%s\n' "$HOME/.local/bin/$name"
    return 0
  fi

  return 1
}

# Scripts and IDEs should not depend on interactive prompt hooks. Keep mise's
# shims on PATH in non-interactive contexts; interactive `mise activate` removes
# the shim directory again when it installs its dynamic PATH hook.
dotfiles_enable_mise_shims() {
  local data_dir shims_dir

  data_dir="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
  shims_dir="$data_dir/shims"

  case ":$PATH:" in
    *":$shims_dir:"*) ;;
    *) export PATH="$shims_dir:$PATH" ;;
  esac
}

dotfiles_mise_env() {
  local platform="$1"
  local profile="$2"

  [[ "$platform" == 'linux' ]] || return 0

  if [[ "$profile" == 'base' ]]; then
    printf '%s\n' 'linux'
  else
    printf 'linux,linux-%s\n' "$profile"
  fi
}
