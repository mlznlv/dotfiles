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

scan_for_secret_pattern() {
  local description="$1"
  local pattern="$2"
  local matches status

  set +e
  matches="$(git grep -l -I -E -- "$pattern" -- . ':(exclude)scripts/check.sh')"
  status=$?
  set -e

  case "$status" in
    0)
      printf 'check: %s detected in tracked file(s):\n' "$description" >&2
      printf '%s\n' "$matches" >&2
      return 1
      ;;
    1)
      return 0
      ;;
    *)
      printf 'check: secret scan failed while checking %s.\n' "$description" >&2
      return "$status"
      ;;
  esac
}

scan_for_secret_pattern \
  'private-key material' \
  '-----BEGIN (((OPENSSH|RSA|DSA|EC|ENCRYPTED) )?PRIVATE KEY|PGP PRIVATE KEY BLOCK)-----'
scan_for_secret_pattern 'age secret key' 'AGE-SECRET-KEY-[A-Z0-9-]+'
scan_for_secret_pattern 'AWS access-key ID' '(AKIA|ASIA)[0-9A-Z]{16}'
scan_for_secret_pattern 'GitHub token' '(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})'

unset -f scan_for_secret_pattern
printf '%s\n' 'check: static and current-tree safety checks passed.'
