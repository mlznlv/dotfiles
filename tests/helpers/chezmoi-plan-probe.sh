#!/usr/bin/env bash

set -u

stat_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

fail_probe() {
    printf 'plan probe rejected an unsafe Chezmoi invocation\n' >&2
    exit "$1"
}

phase=global
expect=
config=
config_format=
source_directory=
destination=
cache=
state=
context=
path_style=
targets=
no_pager=0
no_tty=0
dry_run=0
color=0
progress=0
builtin_diff=0
refresh=0
skip_secrets=0
recursive=0

for argument in "$@"; do
    if [ -n "$expect" ]; then
        case "$expect" in
            config) [ -z "$config" ] || fail_probe 81; config=$argument ;;
            config-format) [ -z "$config_format" ] || fail_probe 81; config_format=$argument ;;
            source) [ -z "$source_directory" ] || fail_probe 81; source_directory=$argument ;;
            destination) [ -z "$destination" ] || fail_probe 81; destination=$argument ;;
            cache) [ -z "$cache" ] || fail_probe 81; cache=$argument ;;
            state) [ -z "$state" ] || fail_probe 81; state=$argument ;;
            context) [ -z "$context" ] || fail_probe 81; context=$argument ;;
            path-style) [ -z "$path_style" ] || fail_probe 81; path_style=$argument ;;
            *) fail_probe 81 ;;
        esac
        expect=
        continue
    fi

    if [ "$phase" = global ]; then
        case "$argument" in
            --no-pager) [ "$no_pager" -eq 0 ] || fail_probe 82; no_pager=1 ;;
            --no-tty) [ "$no_tty" -eq 0 ] || fail_probe 82; no_tty=1 ;;
            --dry-run) [ "$dry_run" -eq 0 ] || fail_probe 82; dry_run=1 ;;
            --color=false) [ "$color" -eq 0 ] || fail_probe 82; color=1 ;;
            --progress=false) [ "$progress" -eq 0 ] || fail_probe 82; progress=1 ;;
            --use-builtin-diff) [ "$builtin_diff" -eq 0 ] || fail_probe 82; builtin_diff=1 ;;
            --refresh-externals=never) [ "$refresh" -eq 0 ] || fail_probe 82; refresh=1 ;;
            --skip-secrets) [ "$skip_secrets" -eq 0 ] || fail_probe 82; skip_secrets=1 ;;
            --config) expect=config ;;
            --config-format) expect=config-format ;;
            --source) expect=source ;;
            --destination) expect=destination ;;
            --cache) expect=cache ;;
            --persistent-state) expect=state ;;
            --override-data-file) expect=context ;;
            status) phase=status ;;
            *) fail_probe 83 ;;
        esac
    else
        case "$argument" in
            --path-style) expect=path-style ;;
            --recursive=false) [ "$recursive" -eq 0 ] || fail_probe 84; recursive=1 ;;
            --*) fail_probe 84 ;;
            *)
                case "$argument" in
                    "$destination"/*) relative_target=${argument#"$destination"/} ;;
                    *) fail_probe 84 ;;
                esac
                targets="${targets}${targets:+
}${relative_target}"
                ;;
        esac
    fi
done

[ -z "$expect" ] || fail_probe 85
[ "$phase" = status ] || fail_probe 85
[ "$no_pager" -eq 1 ] && [ "$no_tty" -eq 1 ] && [ "$dry_run" -eq 1 ] || fail_probe 86
[ "$color" -eq 1 ] && [ "$progress" -eq 1 ] && [ "$builtin_diff" -eq 1 ] || fail_probe 86
[ "$refresh" -eq 1 ] && [ "$skip_secrets" -eq 1 ] || fail_probe 86
[ "$config" = /dev/null ] && [ "$config_format" = toml ] || fail_probe 87
[ "$source_directory" = "$DOTFILES_EXPECTED_SOURCE_HOME" ] || fail_probe 87
[ "$destination" = "$HOME" ] || fail_probe 87
[ "$path_style" = relative ] && [ "$recursive" -eq 1 ] || fail_probe 87
[ -n "$targets" ] && [ "$targets" = "$DOTFILES_EXPECTED_PLAN_TARGETS" ] || fail_probe 88

case "$cache:$state:$context" in
    "$DOTFILES_ALLOWED_TEST_ROOT"/*:"$DOTFILES_ALLOWED_TEST_ROOT"/*:"$DOTFILES_ALLOWED_TEST_ROOT"/*) ;;
    *) fail_probe 89 ;;
esac

plan_private=$(dirname -- "$cache")
render_private=$(dirname -- "$context")
[ "$plan_private" != "$render_private" ] || fail_probe 89
[ "$(dirname -- "$state")" = "$plan_private" ] || fail_probe 89
[ -d "$plan_private" ] && [ ! -L "$plan_private" ] || fail_probe 89
[ -d "$render_private" ] && [ ! -L "$render_private" ] || fail_probe 89
[ -d "$cache" ] && [ ! -L "$cache" ] || fail_probe 89
[ -f "$context" ] && [ ! -L "$context" ] || fail_probe 89

status_log="${plan_private}/status.log"
error_log="${plan_private}/error.log"
records_file="${plan_private}/records.tsv"
[ -f "$status_log" ] && [ -f "$error_log" ] && [ -f "$records_file" ] || fail_probe 89

printf '%s\n%s\n' "$plan_private" "$render_private" >> "$DOTFILES_PLAN_PRIVATE_PATH_LOG"
printf '%s %s %s %s %s %s %s\n' \
    "$(stat_mode "$context")" "$(stat_mode "$render_private")" \
    "$(stat_mode "$plan_private")" "$(stat_mode "$cache")" \
    "$(stat_mode "$status_log")" "$(stat_mode "$error_log")" \
    "$(stat_mode "$records_file")" >> "$DOTFILES_PLAN_PRIVATE_MODE_LOG"
printf 'status\t%s\n' "$(printf '%s' "$targets" | tr '\n' ',')" >> "$DOTFILES_PLAN_INVOCATION_LOG"

case ${DOTFILES_PLAN_PROBE_MODE:-delegate} in
    delegate)
        "$DOTFILES_REAL_CHEZMOI" "$@"
        result=$?
        if [ -e "$state" ]; then
            printf 'state %s\n' "$(stat_mode "$state")" >> "$DOTFILES_PLAN_STATE_MODE_LOG"
        else
            printf 'state absent\n' >> "$DOTFILES_PLAN_STATE_MODE_LOG"
        fi
        exit "$result"
        ;;
    fail)
        exit 97
        ;;
    term)
        kill -TERM "$PPID"
        exit 143
        ;;
    malformed)
        printf 'not a status record\n'
        ;;
    unselected)
        printf ' A .unselected\n'
        ;;
    duplicate)
        first_target=${targets%%$'\n'*}
        printf ' A %s\n A %s\n' "$first_target" "$first_target"
        ;;
    out-of-order)
        first_target=${targets%%$'\n'*}
        last_target=${targets##*$'\n'}
        printf ' A %s\n A %s\n' "$last_target" "$first_target"
        ;;
    deletion)
        first_target=${targets%%$'\n'*}
        printf ' D %s\n' "$first_target"
        ;;
    wrong-effect)
        first_target=${targets%%$'\n'*}
        printf ' M %s\n' "$first_target"
        ;;
    *)
        exit 98
        ;;
esac
