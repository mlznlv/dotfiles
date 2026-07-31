# Remote client setup

This profile installs the client applications and required VS Code extensions. Account sign-in and SSH credentials remain manual.

## Bootstrap

```bash
xcode-select --install
git clone https://github.com/mlznlv/dotfiles.git
cd dotfiles
./bootstrap.sh remote-client
exec zsh -l
```

Then:

1. Sign in to Tailscale.
2. Authenticate GitHub CLI with `gh auth login`.
3. Open VS Code and enable Settings Sync using the GitHub account.
4. Create and configure the SSH key as described below.

## Create an SSH key

Create a separate Ed25519 key for this Mac. Replace the comment with the email or label you use for the machine.

```bash
ssh-keygen -t ed25519 -a 100 -C "macbook-air-remote-client" -f ~/.ssh/id_ed25519
```

Use a passphrase. Do not commit the private key or copy it into this repository.

Start the macOS SSH agent and store the passphrase in Keychain:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Display the public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Add that public key to the remote user's `~/.ssh/authorized_keys` on the development server. The server should be reachable through Tailscale; do not expose SSH publicly.

## Configure the SSH host

Create or edit `~/.ssh/config`:

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

Replace `HostName` and `User` with the actual Tailscale DNS name and Linux account. Protect the files:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

## Verify the connection

Confirm that Tailscale is connected:

```bash
tailscale status
```

Inspect the resolved SSH configuration:

```bash
ssh -G dev | head
```

Connect from the terminal:

```bash
ssh dev
```

On the first connection, verify the host fingerprint through a trusted channel before accepting it.

After terminal SSH works, open VS Code and run:

```text
Remote-SSH: Connect to Host...
```

Select `dev`. Project-specific language extensions should be installed by each project's Dev Container configuration, not by the `remote-client` profile.
