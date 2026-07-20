# Prompt configuration.
#
# Preserve the existing Powerlevel10k UX when a machine already has a managed
# ~/.p10k.zsh, but do not launch a configuration wizard or invent a new prompt
# on hosts where that config has not been captured yet.

P10K_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/powerlevel10k"

if [[ -r "$HOME/.p10k.zsh" && -r "$P10K_HOME/powerlevel10k.zsh-theme" ]]; then
  source "$P10K_HOME/powerlevel10k.zsh-theme"
  source "$HOME/.p10k.zsh"
fi

unset P10K_HOME
