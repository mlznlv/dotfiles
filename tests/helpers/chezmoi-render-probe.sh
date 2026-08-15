#!/usr/bin/env bash

set -u

context=
previous=
for argument in "$@"; do
    if [ "$previous" = --override-data-file ]; then
        context=$argument
        break
    fi
    previous=$argument
done

[ -n "$context" ] && [ -f "$context" ] || exit 91

context_mode=$(stat -c '%a' "$context" 2>/dev/null || stat -f '%Lp' "$context" 2>/dev/null) || exit 92
directory_mode=$(stat -c '%a' "$(dirname -- "$context")" 2>/dev/null || stat -f '%Lp' "$(dirname -- "$context")" 2>/dev/null) || exit 92
[ "$context_mode" = 600 ] && [ "$directory_mode" = 700 ] || exit 93

awk '
    BEGIN {
        allowed["schema"] = 1
        allowed["platform"] = 1
        allowed["modules"] = 1
        allowed["sources"] = 1
        allowed["autosuggestions_artifact"] = 1
    }
    /^\[dotfiles_render\]$/ {
        headers++
        next
    }
    /^[a-z_]+ = / {
        key = $1
        if (!allowed[key] || seen[key]++) invalid = 1
        next
    }
    { invalid = 1 }
    END {
        if (headers != 1 || !seen["schema"] || !seen["platform"] || !seen["modules"] || !seen["sources"]) invalid = 1
        exit invalid
    }
' "$context" || exit 94

grep -Fx 'schema = 1' "$context" >/dev/null 2>&1 || exit 95

printf '%s\n' "$context" >> "$DOTFILES_CONTEXT_PATH_LOG"
printf '%s %s\n' "$context_mode" "$directory_mode" >> "$DOTFILES_CONTEXT_MODE_LOG"
{
    printf '%s\n' '---'
    sed 's/^autosuggestions_artifact = .*/autosuggestions_artifact = "<redacted>"/' "$context"
} >> "$DOTFILES_CONTEXT_SUMMARY_LOG"

case ${DOTFILES_CHEZMOI_PROBE_MODE:-delegate} in
    delegate)
        ;;
    fail)
        exit 97
        ;;
    term)
        kill -TERM "$PPID"
        exit 143
        ;;
    retarget)
        case ${DOTFILES_RETARGET_LINK:-} in
            "$DOTFILES_ALLOWED_TEST_ROOT"/*) ;;
            *) exit 96 ;;
        esac
        rm -f -- "$DOTFILES_RETARGET_LINK"
        ln -s /dev/null "$DOTFILES_RETARGET_LINK"
        ;;
    *)
        exit 98
        ;;
esac

exec "$DOTFILES_REAL_CHEZMOI" "$@"
