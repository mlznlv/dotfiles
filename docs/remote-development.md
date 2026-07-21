# Remote development

## Topology

```text
Ghostty -> Tailscale -> SSH -> dev host -> tmux -> Zsh/Starship
```

Responsibilities:

```text
Ghostty   local terminal UI
Tailscale private network path
OpenSSH   transport/authentication
tmux      persistent remote session
Zsh       remote shell
Starship  prompt
```

Ghostty tabs/splits are for local terminal organization. tmux exists on the dev host primarily for persistence across disconnects, sleep, network changes, or closing the client.

## Connect

With Tailscale connectivity and SSH authorization already configured:

```bash
remote <user>@<host>
```

This attaches to or creates the default tmux session.

Named session:

```bash
remote <user>@<host> backend
```

Detach without stopping remote work:

```text
Ctrl-b d
```

## Machine-specific data

Do not commit:

```text
SSH private keys
real hostnames/IP addresses
Tailscale identity
credentials
corporate VPN/certificate configuration
```

Keep SSH config and identity details local to the machine/environment.

## Ghostty SSH integration

The portable configuration relies on standard OpenSSH and does not enable Ghostty's optional SSH wrapping by default. This keeps remote behavior predictable across terminal emulators and should be revisited only after testing against a real dev host.
