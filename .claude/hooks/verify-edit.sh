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

# Cap the detail fed back into the model's context. A failing catalog repeats
# the same error for every module in every affected check, so the full output is
# long and almost entirely redundant.
MAX_REPORTED_LINES=40

block() {
    heading=$1
    detail=$2

    total=$(printf '%s\n' "$detail" | wc -l | tr -d ' ')
    shown=$(printf '%s\n' "$detail" | head -n "$MAX_REPORTED_LINES")
    if [ "$total" -gt "$MAX_REPORTED_LINES" ]; then
        shown="${shown}
... ${total} lines in total. Rerun the command to see the rest."
    fi

    jq -n --arg reason "${heading}

${shown}" '{
        decision: "block",
        reason: $reason,
        systemMessage: $reason
    }'
    exit 0
}

# Markdown is matched first: a Markdown file under bin, lib, scripts, tests, or
# .chezmoidata is still a documentation file, and scripts/check.sh does not lint
# it.
case "$relative" in
    *.md)
        # The repository lints Markdown in CI. Run the same tool locally only
        # when it is actually resolvable; a bare shim on PATH is not enough, and
        # neither --help nor --version exits 0, so probe with a known-clean file.
        probe_dir=$(mktemp -d)
        printf '# Probe\n' > "${probe_dir}/probe.md"
        markdownlint_ready=1
        markdownlint-cli2 --no-globs "${probe_dir}/probe.md" >/dev/null 2>&1 ||
            markdownlint_ready=0
        rm -rf -- "$probe_dir"

        if [ "$markdownlint_ready" -eq 1 ]; then
            # --no-globs keeps the "globs" entry in .markdownlint-cli2.yaml from
            # widening this run to every Markdown file in the repository, which
            # would report unrelated files as problems in this one.
            if ! output=$(cd "$PROJECT_ROOT" &&
                markdownlint-cli2 --no-globs "$relative" 2>&1); then
                block "markdownlint-cli2 reported problems in ${relative}." \
                    "$output"
            fi
        fi
        ;;
    bin/*|lib/*|scripts/*|tests/*|.chezmoidata/*)
        if ! output=$(cd "$PROJECT_ROOT" && bash scripts/check.sh 2>&1); then
            block "scripts/check.sh failed after editing ${relative}. Fix this before continuing." \
                "$output"
        fi
        ;;
esac

exit 0
