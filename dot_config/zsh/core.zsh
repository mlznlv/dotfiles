# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

# History may contain sensitive command arguments. Do not rely on the ambient
# umask for a file that persists across shells.
if [[ ! -e "$HISTFILE" ]]; then
  : >| "$HISTFILE"
fi
chmod 600 "$HISTFILE" 2>/dev/null || true

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
