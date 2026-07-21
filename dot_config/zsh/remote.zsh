# Remote-development entrypoint.
#
# Connect to an SSH host and create or reattach a persistent tmux session.
remote() {
  local host="${1:-}"
  local session="${2:-main}"

  if (( $# < 1 || $# > 2 )); then
    print -u2 -- "usage: remote <ssh-host> [tmux-session]"
    return 2
  fi

  if [[ -z "$host" || "$host" == -* ]]; then
    print -u2 -- "invalid SSH destination: $host"
    return 2
  fi

  if [[ ! "$session" =~ ^[A-Za-z0-9._-]+$ ]]; then
    print -u2 -- "invalid tmux session name: $session"
    return 2
  fi

  command ssh -t "$host" "tmux new-session -A -s '$session'"
}
