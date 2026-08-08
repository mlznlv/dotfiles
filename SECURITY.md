# Security Policy

## Project status

The replacement solution is not released or installable yet. Supported versions will be listed here when the first release is published.

## Reporting a vulnerability

Do not disclose vulnerabilities, credentials, private infrastructure, or exploit details in a public issue.

Use GitHub private vulnerability reporting for this repository when available. If it is unavailable, contact the maintainer through a private method listed on the maintainer's GitHub profile and include:

- The affected component or document.
- Reproduction steps.
- Potential impact.
- Suggested mitigation, if known.
- Whether the issue has been disclosed elsewhere.

The maintainer will acknowledge a valid private report, assess impact, and coordinate a fix and disclosure timeline.

## Scope

Security reports may cover:

- Bootstrap trust and integrity.
- Privilege boundaries.
- Unsafe file replacement or deletion.
- Package-provider ownership violations.
- Command injection.
- Secret or identity exposure.
- Untrusted profile or module behavior.
- Supply-chain risks in workflows and dependencies.

General support requests and feature proposals belong in the public issue tracker.

## Secrets

This repository must never contain credentials, private keys, certificates, tokens, real hostnames or IP addresses, Tailscale identity, private registry configuration, or machine-specific Git identity.

If a secret is committed, removing it from the latest tree is not sufficient. Revoke or rotate it first, then assess and sanitize Git history.
