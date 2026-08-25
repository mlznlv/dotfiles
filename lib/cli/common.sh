# Source-only CLI common functions: help, platform handling, and required components.

usage() {
    cat <<'EOF'
Usage:
  dotfiles help
  dotfiles version
  dotfiles catalog validate
  dotfiles module list [--platform macos|debian | --all]
  dotfiles module show <module-id>
  dotfiles profile list [--platform macos|debian | --all]
  dotfiles profile show <profile-id>
  dotfiles resolve [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]
  dotfiles config set (--profile <profile-id> | --modules <id,id>) [--add <id,id>] [--platform macos|debian]
  dotfiles config interactive [--platform macos|debian]
  dotfiles config inspect [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]
  dotfiles config doctor [--platform macos|debian]
  dotfiles prerequisite check [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]
  dotfiles plan [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian]
  dotfiles apply [--profile <profile-id> | --modules <id,id>] [--add <id,id>] [--platform macos|debian] [--yes]

Config set changes only private local selection state. Apply changes only confirmed selected configuration.
Config interactive requires terminal stdin and changes only confirmed private local selection state.
Config inspect and doctor are read-only and diagnose only selection intent and its catalog composition.
Resolve, prerequisite check, plan, and apply load saved selection only when an explicit base is omitted.
EOF
}
usage_error() {
    printf 'error: %s\n' "$1" >&2
    printf 'Run dotfiles help for usage.\n' >&2
    exit 2
}

validate_platform() {
    case "$1" in
        macos|debian)
            return 0
            ;;
        *)
            printf 'error: unsupported platform %s\n' "$1" >&2
            return 3
            ;;
    esac
}

detect_platform() {
    system_name=$(uname -s 2>/dev/null || true)
    case "$system_name" in
        Darwin)
            printf 'macos\n'
            return 0
            ;;
        Linux)
            if [ -r /etc/os-release ]; then
                os_id=$(sed -n 's/^ID=//p' /etc/os-release | head -n 1 | tr -d '"')
                os_like=$(sed -n 's/^ID_LIKE=//p' /etc/os-release | head -n 1 | tr -d '"')
                case " ${os_id} ${os_like} " in
                    *debian*|*ubuntu*|*kali*)
                        printf 'debian\n'
                        return 0
                        ;;
                esac
            fi
            ;;
    esac
    printf 'error: unsupported operating system\n' >&2
    return 3
}

config_require_state_program() {
    if [ ! -f "$CONFIG_STATE_PROGRAM" ]; then
        printf 'error: local selection state implementation is missing\n' >&2
        return 4
    fi

    # shellcheck source=../lib/config-state.sh
    source "$CONFIG_STATE_PROGRAM"
}
