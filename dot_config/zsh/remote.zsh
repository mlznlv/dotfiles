# Remote-development entrypoint.
#
# Connect to an SSH host and create or reattach a persistent tmux session.
remote() {
  local host="${1:-}"
  local session="${2:-main}"

  if [[ -z "$host" ]]; then
    echo "usage: remote <ssh-host> [tmux-session]" >&2
    return 2
  fi

  if [[ ! "$session" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "invalid tmux session name: $session" >&2
    return 2
  fi

  ssh -t "$host" "tmux new-session -A -s '$session'"
}
