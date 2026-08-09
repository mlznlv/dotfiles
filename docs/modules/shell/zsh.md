# Zsh

`shell.zsh` is the primary interactive shell module for macOS and Debian-family
Linux. It requests `zsh` from Homebrew on macOS and mise on Debian.

The released module is catalog metadata only. Provider observation, package
installation, managed `.zshrc` state, planning, and apply are not available.

~~~console
./bin/dotfiles module show shell.zsh
./bin/dotfiles resolve --modules shell.zsh --platform debian
~~~
