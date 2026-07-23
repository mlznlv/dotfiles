#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SOURCE_DIR"

required_files=(
  .chezmoiignore
  .gitignore
  README.md
  bootstrap.sh
  update.sh
  homebrew/Brewfile
  homebrew/Brewfile.local-dev
  homebrew/Brewfile.remote-client
  mise/config.toml
  mise/config.linux.toml
  mise/config.linux-dev-host.toml
  mise/runtime.toml
  mise/runtime.linux.toml
  mise/runtime.macos-local-dev.toml
  dot_zprofile
  dot_zshrc
  dot_vimrc
  dot_config/zsh/prompt.zsh
  dot_config/ghostty/config.ghostty
  docs/architecture.md
  docs/shell-and-terminal.md
  docs/runtimes.md
  docs/remote-development.md
  docs/maintenance.md
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    printf 'check: required file is missing: %s\n' "$file" >&2
    exit 1
  fi
done
unset required_files

for file in bootstrap.sh update.sh scripts/*.sh; do
  bash -n "$file"
done

if command -v zsh >/dev/null 2>&1; then
  while IFS= read -r -d '' file; do
    zsh -n "$file"
  done < <(find dot_config/zsh -type f -name '*.zsh' -print0)
  zsh -n dot_zprofile
  zsh -n dot_zshrc
else
  printf '%s\n' 'check: zsh not found; skipped Zsh syntax validation.' >&2
fi

EMPTY_TREE="$(git hash-object -t tree /dev/null)"
git diff --check "$EMPTY_TREE" HEAD -- .
unset EMPTY_TREE

CONFLICT_FILES="$(git grep -l -I -E '^(<<<<<<< .+|=======|>>>>>>> .+)$' -- . || true)"
if [[ -n "$CONFLICT_FILES" ]]; then
  printf '%s\n' 'check: unresolved merge-conflict markers detected:' >&2
  printf '%s\n' "$CONFLICT_FILES" >&2
  exit 1
fi
unset CONFLICT_FILES

# `.gitignore` is the single path-policy source of truth. A tracked file that
# matches it was likely force-added or became forbidden after it was committed.
IGNORED_TRACKED="$(git ls-files -ci --exclude-standard)"
if [[ -n "$IGNORED_TRACKED" ]]; then
  printf '%s\n' 'check: tracked files violate .gitignore safety policy:' >&2
  printf '%s\n' "$IGNORED_TRACKED" >&2
  exit 1
fi
unset IGNORED_TRACKED

# Package/profile ownership invariants.
if grep -Eq '^[[:space:]]*cask[[:space:]]+"ghostty"' homebrew/Brewfile; then
  printf '%s\n' 'check: Ghostty must be profile-owned, not part of the minimal macOS base.' >&2
  exit 1
fi
for file in homebrew/Brewfile.local-dev homebrew/Brewfile.remote-client; do
  if ! grep -Eq '^[[:space:]]*cask[[:space:]]+"ghostty"' "$file"; then
    printf 'check: Ghostty declaration missing from %s.\n' "$file" >&2
    exit 1
  fi
done
if ! grep -Eq '^[[:space:]]*brew[[:space:]]+"vim"' homebrew/Brewfile; then
  printf '%s\n' 'check: macOS base must provide Vim explicitly.' >&2
  exit 1
fi
if ! grep -Eq '^[[:space:]]*"apt:vim"[[:space:]]*=' mise/config.linux.toml; then
  printf '%s\n' 'check: Linux base must provide Vim explicitly.' >&2
  exit 1
fi
if ! grep -Eq '^[[:space:]]*starship[[:space:]]*=[[:space:]]*"' mise/runtime.linux.toml; then
  printf '%s\n' 'check: Linux platform runtime layer must provide Starship.' >&2
  exit 1
fi
if ! grep -Eq '^[[:space:]]*syntax[[:space:]]+enable' dot_vimrc || \
   ! grep -Eq '^[[:space:]]*filetype[[:space:]]+plugin[[:space:]]+indent[[:space:]]+on' dot_vimrc; then
  printf '%s\n' 'check: Vim must enable native syntax and filetype detection by default.' >&2
  exit 1
fi
for path in \
  '~/.vim/pack/dotfiles/start/fzf' \
  '~/.vim/pack/dotfiles/start/fzf.vim' \
  '~/.vim/pack/dotfiles/start/vim-surround' \
  '~/.vim/pack/dotfiles/start/vim-repeat' \
  '~/.vim/pack/dotfiles/start/vim-sleuth' \
  '~/.vim/pack/dotfiles/start/vim-gitgutter'; do
  if ! grep -Fq "\"$path\" = { url =" mise/config.toml; then
    printf 'check: managed Vim repository missing from mise config: %s\n' "$path" >&2
    exit 1
  fi
done
for path in README.md .gitignore bootstrap.sh update.sh homebrew mise docs scripts .github; do
  if ! grep -Fxq "$path" .chezmoiignore; then
    printf 'check: repository-only path is missing from .chezmoiignore: %s\n' "$path" >&2
    exit 1
  fi
done

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
scan_for_secret_pattern 'Slack token' 'xox[baprs]-[A-Za-z0-9-]{10,}'
scan_for_secret_pattern 'Google API key' 'AIza[0-9A-Za-z_-]{30,}'

unset -f scan_for_secret_pattern
printf '%s\n' 'check: static, consistency, and current-tree safety checks passed.'
