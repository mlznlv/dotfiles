#!/usr/bin/env bash

# PostToolUse hook. Re-runs the checks that cover the file Claude just edited so
# a broken record contract or manifest surfaces immediately instead of at commit
# time. Reads the Claude Code hook payload on standard input.
#
# The report is advisory and never blocks. A coordinated change such as the
# four-place manifest field edit described in .claude/skills/catalog-field leaves
# the repository briefly inconsistent by design; a blocking hook would interrupt
# that documented workflow three times with errors that are artifacts of the
# half-applied change rather than real defects.
#
# It only sees edits made with the Write and Edit tools. A file rewritten through
# Bash, with sed -i or a heredoc, is not verified here.

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)

MAX_REPORTED_LINES=40

# jq may be present on PATH as a version manager's shim that cannot resolve an
# interpreter, so presence is not enough. Say so rather than exiting silently:
# a quiet no-op is indistinguishable from a passing check.
if ! printf '{}' | jq . >/dev/null 2>&1; then
    printf '%s\n' '{"systemMessage":"verify-edit hook skipped: jq is not usable, so this edit was not verified."}'
    exit 0
fi

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

# One line for the user, the capped detail for the model.
report() {
    summary=$1
    detail=$2

    total=$(printf '%s\n' "$detail" | wc -l | tr -d ' ')
    shown=$(printf '%s\n' "$detail" | head -n "$MAX_REPORTED_LINES")
    if [ "$total" -gt "$MAX_REPORTED_LINES" ]; then
        shown="${shown}
... ${total} lines in total. Run the command again for the rest."
    fi

    jq -n --arg summary "$summary" --arg context "${summary}

${shown}" '{
        systemMessage: $summary,
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $context
        }
    }'
    exit 0
}

# Markdown is matched first: a Markdown file under bin, lib, scripts, tests, or
# .chezmoidata is still a documentation file, and scripts/check.sh does not lint
# it.
case "$relative" in
    *.md)
        # Neither --help nor --version exits 0, so probe with a known-clean file.
        probe_dir=$(mktemp -d)
        printf '# Probe\n' > "${probe_dir}/probe.md"
        markdownlint_ready=1
        markdownlint-cli2 --no-globs "${probe_dir}/probe.md" >/dev/null 2>&1 ||
            markdownlint_ready=0
        rm -rf -- "$probe_dir"

        if [ "$markdownlint_ready" -eq 1 ]; then
            # --no-globs keeps the "globs" entry in .markdownlint-cli2.yaml from
            # widening this run to every Markdown file in the repository.
            if ! output=$(cd "$PROJECT_ROOT" &&
                markdownlint-cli2 --no-globs "$relative" 2>&1); then
                report "markdownlint-cli2 reported problems in ${relative}." \
                    "$output"
            fi
        fi
        ;;
    bin/*|lib/*|scripts/*|tests/*|.chezmoidata/*)
        if ! output=$(cd "$PROJECT_ROOT" && bash scripts/check.sh 2>&1); then
            report "scripts/check.sh does not pass after editing ${relative}. This is expected midway through a coordinated change." \
                "$output"
        fi
        ;;
esac

exit 0
