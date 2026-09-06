#!/usr/bin/env bash

# PostToolUse hook. Re-runs the checks that cover the file Claude just edited so
# a broken record contract or manifest surfaces immediately instead of at commit
# time. Reads the Claude Code hook payload on standard input.
#
# Silent on success. On failure it returns a blocking decision whose reason is
# fed back to Claude and shown to the user.

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
file_path=$(printf '%s' "$payload" |
    jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)
[ -n "$file_path" ] || exit 0

case "$file_path" in
    "${PROJECT_ROOT}"/*)
        relative=${file_path#"${PROJECT_ROOT}/"}
        ;;
    /*)
        exit 0
        ;;
    *)
        relative=$file_path
        ;;
esac

block() {
    jq -n --arg reason "$1" '{
        decision: "block",
        reason: $reason,
        systemMessage: $reason
    }'
    exit 0
}

case "$relative" in
    bin/*|lib/*|scripts/*|tests/*|.chezmoidata/*)
        if ! output=$(cd "$PROJECT_ROOT" && bash scripts/check.sh 2>&1); then
            block "scripts/check.sh failed after editing ${relative}. Fix this before continuing.

${output}"
        fi
        ;;
    *.md)
        # The repository lints Markdown in CI. Run the same tool locally only
        # when it is actually resolvable; a bare shim on PATH is not enough.
        if markdownlint-cli2 --help >/dev/null 2>&1; then
            if ! output=$(cd "$PROJECT_ROOT" && markdownlint-cli2 "$relative" 2>&1); then
                block "markdownlint-cli2 reported problems in ${relative}.

${output}"
            fi
        fi
        ;;
esac

exit 0
