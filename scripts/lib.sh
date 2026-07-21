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
  printf '%s\n' '  macOS: base, local-dev, remote-client'
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

dotfiles_require_supported_linux() {
  local platform="$1"

  [[ "$platform" != 'linux' ]] && return 0
  if ! command -v apt-get >/dev/null 2>&1; then
    printf '%s\n' 'Unsupported Linux distribution: apt-get is required.' >&2
    printf '%s\n' 'This repository currently supports Ubuntu/Debian Linux hosts.' >&2
    return 1
  fi
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
