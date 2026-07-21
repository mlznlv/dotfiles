# Maintenance

## Routine update

Use the same profile that provisioned the machine:

```bash
cd ~/.local/share/chezmoi
bash ./update.sh local-dev
exec zsh -l
```

Other profiles:

```bash
bash ./update.sh remote-client
bash ./update.sh dev-host
```

`update.sh` performs:

```text
git pull --ff-only
-> apply latest declarations
-> macOS: native Homebrew upgrades
-> Linux: managed apt upgrades
-> update managed Zsh repositories
-> upgrade mise runtimes within configured ranges
-> health/convergence checks
```

It does not run blanket `brew autoremove`, destructive cleanup, or mise's Homebrew backend on macOS.

## Verification

After bootstrap/update:

```bash
mise doctor
mise current
chezmoi diff
```

On macOS:

```bash
brew bundle check --file="$HOME/.local/share/chezmoi/homebrew/Brewfile"
```

On `local-dev`:

```bash
brew bundle check --file="$HOME/.local/share/chezmoi/homebrew/Brewfile.local-dev"
```

`chezmoi diff` should normally be empty.

## Prompt diagnostics

```bash
starship --version
prompt-preset
prompt-module status
printf '%s\n' "$STARSHIP_CONFIG"
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

## Reapply configuration

```bash
cd ~/.local/share/chezmoi
./bootstrap.sh <profile>
exec zsh -l
```

Use `bootstrap.sh` for provisioning/convergence and `update.sh` for routine maintenance.
