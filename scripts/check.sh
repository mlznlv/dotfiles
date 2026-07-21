#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SOURCE_DIR"

for file in bootstrap.sh update.sh scripts/*.sh; do
  bash -n "$file"
done

if command -v zsh >/dev/null 2>&1; then
  for file in dot_zprofile dot_zshrc dot_config/zsh/*.zsh; do
    zsh -n "$file"
  done
else
  printf '%s\n' 'check: zsh not found; skipped Zsh syntax validation.' >&2
fi

git diff --check

TRACKED_SENSITIVE_PATHS="$(
  git ls-files | grep -E \
    '(^|/)[^/]*dot_(ssh|aws|kube|azure|gnupg)(/|$)|(^|/)[^/]*dot_(git-credentials|netrc|npmrc|pypirc|zsh_history)$|(^|/)[^/]*dot_config/[^/]*zsh/local\.zsh$|(^|/)[^/]*dot_config/[^/]*mise/[^/]*conf\.d/90-machine-local\.toml$|(^|/)[^/]*dot_config/[^/]*starship/(preset|modules)$|(^|/)[^/]*dot_config/[^/]*(gcloud|gh)(/|$)|(^|/)[^/]*dot_docker/config\.json$|(^|/)[^/]*dot_terraform\.d/credentials\.tfrc\.json$|(^|/)[^/]*dot_(m2/settings\.xml|gradle/gradle\.properties|cargo/credentials\.toml)$' \
    || true
)"

if [[ -n "$TRACKED_SENSITIVE_PATHS" ]]; then
  printf '%s\n' 'check: tracked credential/identity or machine-local paths are forbidden:' >&2
  printf '%s\n' "$TRACKED_SENSITIVE_PATHS" >&2
  exit 1
fi

if git grep -n -I -E -- \
  '-----BEGIN (OPENSSH|RSA|DSA|EC|PGP) PRIVATE KEY-----' \
  -- . \
  ':(exclude)scripts/check.sh'; then
  printf '%s\n' 'check: private-key material detected in the current tree.' >&2
  exit 1
fi

printf '%s\n' 'check: static and current-tree safety checks passed.'
