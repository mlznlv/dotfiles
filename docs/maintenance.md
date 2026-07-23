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
-> repository static/safety checks
-> self-update mise when supported
-> apply latest declarations
-> validate mise config loading
-> upgrade chezmoi when supported
-> macOS: native Homebrew upgrades
-> Ubuntu/Debian: managed apt upgrades
-> update managed Zsh repositories
-> upgrade mise runtimes/versioned tools within configured ranges
-> non-interactive mise + package + chezmoi convergence checks
```

Scripts put mise shims on `PATH` explicitly; they do not depend on interactive prompt hooks. `mise doctor` is intentionally not run inside `update.sh` because its shell-activation diagnostics are meaningful after restarting an interactive shell.

It does not run blanket `brew autoremove`, destructive cleanup, or mise's Homebrew backend on macOS.

## Repository checks

Run after changing repository code/config:

```bash
bash scripts/check.sh
```

It validates required repository structure, Bash/Zsh syntax, whole-tree whitespace and conflict markers, package/profile ownership, chezmoi projection boundaries, tracked files that violate `.gitignore`, and high-signal secret material in the current tree. Secret matches report filenames only, not matched values.

The same check runs in GitHub Actions on macOS and Ubuntu for pull requests and on pushes to `master`.

This is a guardrail, not a full secret/history scanner. Before publishing an existing repository, inspect the full Git history separately.

## Verification

After bootstrap/update, restart the shell first:

```bash
exec zsh -l
```

Then verify:

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
