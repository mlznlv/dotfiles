# Remote client setup

The `remote-client` profile installs Ghostty, Tailscale, VS Code, and the baseline remote-development extensions. Account sign-in and SSH credentials remain manual.

## 1. Install

```bash
xcode-select --install
mkdir -p ~/.local/share
git clone https://github.com/mlznlv/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./bootstrap.sh remote-client
exec zsh -l
```

## 2. Sign in

1. Open Tailscale, approve the VPN/system extension if prompted, and sign in.
2. In Tailscale, open **Settings → CLI integration** and install the CLI launcher.
3. Open VS Code and enable **Settings Sync** with GitHub.
4. Optional: authenticate GitHub CLI with `gh auth login`.

## 3. Create an SSH key

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 100 -C "macbook-air-remote-client" -f ~/.ssh/id_ed25519
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

Use a passphrase. Add only the printed public key to the remote user's `~/.ssh/authorized_keys`. Never copy or commit the private key.

## 4. Configure SSH

Create `~/.ssh/config`:

```sshconfig
Host dev
  HostName dev-server.example.ts.net
  User developer
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

Replace `HostName` with the Tailscale DNS name and `User` with the Linux account.

```bash
chmod 600 ~/.ssh/config ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

## 5. Verify

```bash
code --list-extensions
tailscale status
ssh -G dev >/dev/null
ssh dev
```

The extension list must include Remote SSH, Remote Explorer, Dev Containers, Containers, GitLens, EditorConfig, and Error Lens. Verify the server fingerprint through a trusted channel before accepting it.

After terminal SSH works, in VS Code run:

```text
Remote-SSH: Connect to Host...
```

Select `dev`. Project-specific extensions belong in each project's Dev Container configuration.
