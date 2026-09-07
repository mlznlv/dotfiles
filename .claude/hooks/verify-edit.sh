#!/usr/bin/env bash

# PostToolUse hook. Runs the fast structural guards that cover the file Claude
# just edited, so a maintained-source violation surfaces at edit time instead of
# at review time. Reads the Claude Code hook payload on standard input.
#
# It deliberately does not run scripts/check.sh. The full gate takes about five
# minutes, and tests/maintainability.sh alone takes over two, which is unusable
# after every edit. The guards it does run take about one second together and
# catch what an edit actually breaks: a file crossing its line budget, a NUL
# byte, an over-long physical line, or loader-manifest drift.
#
# The report is advisory and never blocks. A coordinated change is inconsistent
# partway through by design, and a blocking hook would interrupt the documented
# workflows.
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

case "$relative" in
    *.md)
        # Narrative documentation is outside the maintained-source rule, so only
        # the Markdown linter applies. Neither --help nor --version exits 0, so
        # probe with a known-clean file.
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
                report "markdownlint-cli2 reported problems in ${relative}." "$output"
            fi
        fi
        ;;
    .chezmoidata/*|.github/workflows/*|bin/*|home/*|lib/*|scripts/*|tests/*)
        # The governed roots. check-maintainability enforces the line budgets,
        # NUL and long-line rules, and the fixed-loader manifests; the branch
        # policy check guards the documented branch contract.
        if ! output=$(cd "$PROJECT_ROOT" && bash scripts/check-maintainability.sh 2>&1); then
            report "Maintained-source guard fails after editing ${relative}." "$output"
        fi
        if ! output=$(cd "$PROJECT_ROOT" && bash scripts/check-branch-policy.sh 2>&1); then
            report "Branch policy check fails after editing ${relative}." "$output"
        fi
        case "$relative" in
            *.sh|bin/dotfiles)
                if ! output=$(cd "$PROJECT_ROOT" && bash -n "$relative" 2>&1); then
                    report "bash -n reports a syntax error in ${relative}." "$output"
                fi
                ;;
        esac
        case "$relative" in
            .chezmoidata/*)
                if ! output=$(cd "$PROJECT_ROOT" && ./bin/dotfiles catalog validate 2>&1); then
                    report "catalog validate fails after editing ${relative}." "$output"
                fi
                ;;
        esac
        ;;
esac

exit 0
