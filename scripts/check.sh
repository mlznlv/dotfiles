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

# `.gitignore` is the single path-policy source of truth. A tracked file that
# matches it was likely force-added or became forbidden after it was committed.
IGNORED_TRACKED="$(git ls-files -ci --exclude-standard)"
if [[ -n "$IGNORED_TRACKED" ]]; then
  printf '%s\n' 'check: tracked files violate .gitignore safety policy:' >&2
  printf '%s\n' "$IGNORED_TRACKED" >&2
  exit 1
fi
unset IGNORED_TRACKED

if git grep -n -I -E -- \
  '-----BEGIN (OPENSSH|RSA|DSA|EC|PGP) PRIVATE KEY-----' \
  -- . \
  ':(exclude)scripts/check.sh'; then
  printf '%s\n' 'check: private-key material detected in the current tree.' >&2
  exit 1
fi

printf '%s\n' 'check: static and current-tree safety checks passed.'
