# Minimal shell

`shell.minimal` is the first curated profile for macOS and Debian-family Linux.
It contains `shell.zsh`, `shell.zsh.autosuggestions`, and `prompt.starship`.

~~~console
$ ./bin/dotfiles resolve --profile shell.minimal --platform debian
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

The profile previews catalog intent only. It does not observe or invoke
providers, install packages, manage home files, create a plan, or apply changes.
