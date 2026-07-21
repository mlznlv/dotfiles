# Maintenance

## Routine update

Always pass the profile that provisioned the machine:

```bash
cd ~/.local/share/chezmoi
bash ./update.sh local-dev
exec zsh -l
```

Other examples:

```bash
bash ./update.sh remote-client
bash ./update.sh dev-host
```

`bootstrap.sh` and `update.sh` intentionally refuse to run without an explicit profile.

`update.sh` performs:

```text
git pull --ff-only
-> apply latest declarations
-> macOS: native Homebrew upgrades
-> Ubuntu/Debian: managed apt upgrades
-> update managed Zsh repositories
-> upgrade mise runtimes/versioned tools within configured ranges
-> mise + package + chezmoi convergence checks
```

It does not run blanket `brew autoremove`, destructive cleanup, or mise's Homebrew backend on macOS.

## Repository checks

Run after changing repository code/config:

```bash
bash scripts/check.sh
```

It validates Bash syntax, Zsh syntax when Zsh is available, `git diff --check`, forbidden tracked credential/identity paths, and private-key material in the current tree.

This is a guardrail, not a full secret/history scanner. Before publishing an existing repository, inspect the full Git history separately.

## Verification

After bootstrap/update:

```bash
mise config ls
mise doctor
mise current
mise bootstrap status --missing
chezmoi diff
```

`mise bootstrap status --missing` and `chezmoi diff` should normally produce no missing/unapplied state.

On macOS:

```bash
brew bundle check --file="$HOME/.local/share/chezmoi/homebrew/Brewfile"
```

On `local-dev` also check:

```bash
brew bundle check --file="$HOME/.local/share/chezmoi/homebrew/Brewfile.local-dev"
```

## Shell/prompt diagnostics

```bash
starship --version
prompt-preset
prompt-module status
printf '%s\n' "$STARSHIP_CONFIG"
```

Check interactive plugins:

```bash
whence -w _zsh_highlight
whence -w _zsh_autosuggest_start
```

Reset prompt state:

```bash
prompt-preset default
prompt-module reset
exec zsh -l
```

## Homebrew diagnostics

Do not delete or overwrite files in `/opt/homebrew` merely to make bootstrap/update pass.

Start with:

```bash
command -v brew
brew --prefix
brew doctor
brew bundle check --file="$HOME/.local/share/chezmoi/homebrew/Brewfile"
```

Avoid `brew link --overwrite`, broad `brew autoremove`, and destructive cleanup unless the exact ownership problem has been established first.

Static checks do not replace a real bootstrap/update smoke test on each supported platform/profile before release.
