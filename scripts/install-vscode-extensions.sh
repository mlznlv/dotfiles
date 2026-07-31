#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTENSIONS_FILE="${1:-$SOURCE_DIR/editor/vscode/extensions.remote-client.txt}"

if [[ ! -f "$EXTENSIONS_FILE" ]]; then
  echo "VS Code extensions file was not found: $EXTENSIONS_FILE" >&2
  exit 1
fi

VSCODE_CLI=""
if command -v code >/dev/null 2>&1; then
  VSCODE_CLI="$(command -v code)"
elif [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  VSCODE_CLI="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
else
  echo "VS Code CLI was not found." >&2
  echo "Expected the Homebrew cask application at /Applications/Visual Studio Code.app." >&2
  exit 1
fi

while IFS= read -r extension || [[ -n "$extension" ]]; do
  extension="${extension%%#*}"
  extension="${extension//[[:space:]]/}"
  [[ -z "$extension" ]] && continue

  echo "Installing VS Code extension: $extension"
  "$VSCODE_CLI" --install-extension "$extension"
done < "$EXTENSIONS_FILE"

echo "VS Code extensions installed successfully."
