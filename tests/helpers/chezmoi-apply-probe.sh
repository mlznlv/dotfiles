#!/usr/bin/env bash

set -u

stat_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

fail_probe() {
    printf 'apply probe rejected an unsafe Chezmoi invocation\n' >&2
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
target=
no_pager=0
no_tty=0
color=0
progress=0
builtin_diff=0
builtin_age=0
builtin_git=0
refresh=0
interactive=0
mode_file=0
force=0
include=0
exclude=0
recursive=0
parent_dirs=0

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
            *) fail_probe 81 ;;
        esac
        expect=
        continue
    fi

    if [ "$phase" = global ]; then
        case "$argument" in
            --no-pager) [ "$no_pager" -eq 0 ] || fail_probe 82; no_pager=1 ;;
            --no-tty) [ "$no_tty" -eq 0 ] || fail_probe 82; no_tty=1 ;;
            --color=false) [ "$color" -eq 0 ] || fail_probe 82; color=1 ;;
            --progress=false) [ "$progress" -eq 0 ] || fail_probe 82; progress=1 ;;
            --use-builtin-diff) [ "$builtin_diff" -eq 0 ] || fail_probe 82; builtin_diff=1 ;;
            --use-builtin-age=true) [ "$builtin_age" -eq 0 ] || fail_probe 82; builtin_age=1 ;;
            --use-builtin-git=true) [ "$builtin_git" -eq 0 ] || fail_probe 82; builtin_git=1 ;;
            --refresh-externals=never) [ "$refresh" -eq 0 ] || fail_probe 82; refresh=1 ;;
            --interactive=false) [ "$interactive" -eq 0 ] || fail_probe 82; interactive=1 ;;
            --mode=file) [ "$mode_file" -eq 0 ] || fail_probe 82; mode_file=1 ;;
            --force) [ "$force" -eq 0 ] || fail_probe 82; force=1 ;;
            --config) expect=config ;;
            --config-format) expect=config-format ;;
            --source) expect=source ;;
            --destination) expect=destination ;;
            --cache) expect=cache ;;
            --persistent-state) expect=state ;;
            --override-data-file) expect=context ;;
            apply) phase=apply ;;
            --dry-run|--keep-going|--source-path|init|update|add|remove|purge|destroy|forget) fail_probe 83 ;;
            *) fail_probe 83 ;;
        esac
    else
        case "$argument" in
            --include=dirs,files) [ "$include" -eq 0 ] || fail_probe 84; include=1 ;;
            --exclude=encrypted,externals,scripts,symlinks) [ "$exclude" -eq 0 ] || fail_probe 84; exclude=1 ;;
            --recursive=false) [ "$recursive" -eq 0 ] || fail_probe 84; recursive=1 ;;
            --parent-dirs) [ "$parent_dirs" -eq 0 ] || fail_probe 84; parent_dirs=1 ;;
            --*) fail_probe 84 ;;
            *) [ -z "$target" ] || fail_probe 84; target=$argument ;;
        esac
    fi
done

[ -z "$expect" ] && [ "$phase" = apply ] || fail_probe 85
[ "$no_pager" -eq 1 ] && [ "$no_tty" -eq 1 ] || fail_probe 86
[ "$color" -eq 1 ] && [ "$progress" -eq 1 ] && [ "$builtin_diff" -eq 1 ] || fail_probe 86
[ "$builtin_age" -eq 1 ] && [ "$builtin_git" -eq 1 ] && [ "$refresh" -eq 1 ] || fail_probe 86
[ "$interactive" -eq 1 ] && [ "$mode_file" -eq 1 ] && [ "$force" -eq 1 ] || fail_probe 86
[ "$include" -eq 1 ] && [ "$exclude" -eq 1 ] && [ "$recursive" -eq 1 ] && [ "$parent_dirs" -eq 1 ] || fail_probe 86
[ "$config" = /dev/null ] && [ "$config_format" = toml ] || fail_probe 87
[ "$source_directory" = "$DOTFILES_EXPECTED_SOURCE_HOME" ] || fail_probe 87
[ "$destination" = "$HOME" ] || fail_probe 87
case "$target" in "$destination"/*) relative_target=${target#"$destination"/} ;; *) fail_probe 87 ;; esac
case "${DOTFILES_EXPECTED_APPLY_TARGETS:-}" in
    "$relative_target"|"$relative_target"$'\n'*|*$'\n'"$relative_target"|*$'\n'"$relative_target"$'\n'*) ;;
    *) fail_probe 88 ;;
esac

case "$cache:$state:$context" in
    "$DOTFILES_ALLOWED_TEST_ROOT"/*:"$DOTFILES_ALLOWED_TEST_ROOT"/*:"$DOTFILES_ALLOWED_TEST_ROOT"/*) ;;
    *) fail_probe 89 ;;
esac
apply_private=$(dirname -- "$cache")
render_private=$(dirname -- "$context")
[ -f "${apply_private}/records.tsv" ] || fail_probe 89
[ -f "${apply_private}/apply-output.log" ] || fail_probe 89
[ -f "${apply_private}/apply-error.log" ] || fail_probe 89
[ -f "${apply_private}/apply-recheck.log" ] || fail_probe 89
[ "$apply_private" != "$render_private" ] || fail_probe 89
[ "$(dirname -- "$state")" = "$apply_private" ] || fail_probe 89
[ -d "$apply_private" ] && [ ! -L "$apply_private" ] || fail_probe 89
[ -d "$render_private" ] && [ ! -L "$render_private" ] || fail_probe 89
[ -d "$cache" ] && [ ! -L "$cache" ] || fail_probe 89
[ -f "$context" ] && [ ! -L "$context" ] || fail_probe 89

printf '%s\n%s\n' "$apply_private" "$render_private" >> "$DOTFILES_APPLY_PRIVATE_PATH_LOG"
printf '%s %s %s %s %s %s %s %s\n' "$(stat_mode "$context")" "$(stat_mode "$render_private")" \
    "$(stat_mode "$apply_private")" "$(stat_mode "$cache")" \
    "$(stat_mode "${apply_private}/records.tsv")" "$(stat_mode "${apply_private}/apply-output.log")" \
    "$(stat_mode "${apply_private}/apply-error.log")" "$(stat_mode "${apply_private}/apply-recheck.log")" \
    >> "$DOTFILES_APPLY_PRIVATE_MODE_LOG"
printf 'apply\t%s\n' "$relative_target" >> "$DOTFILES_APPLY_INVOCATION_LOG"

run_real_apply() {
    "$DOTFILES_REAL_CHEZMOI" "$@"
}

case ${DOTFILES_APPLY_PROBE_MODE:-delegate} in
    delegate)
        run_real_apply "$@"
        ;;
    fail-target)
        if [ "$relative_target" = "$DOTFILES_APPLY_PROBE_TARGET" ]; then
            exit 97
        fi
        run_real_apply "$@"
        ;;
    wrong-bytes)
        run_real_apply "$@" || exit $?
        if [ "$relative_target" = "$DOTFILES_APPLY_PROBE_TARGET" ]; then
            printf 'wrong bytes after reported success\n' > "$target"
        fi
        ;;
    disappear)
        run_real_apply "$@" || exit $?
        if [ "$relative_target" = "$DOTFILES_APPLY_PROBE_TARGET" ]; then
            rm -f -- "$target"
        fi
        ;;
    replace-symlink)
        run_real_apply "$@" || exit $?
        if [ "$relative_target" = "$DOTFILES_APPLY_PROBE_TARGET" ]; then
            rm -f -- "$target"
            ln -s /dev/null "$target"
        fi
        ;;
    swap-next-symlink)
        run_real_apply "$@" || exit $?
        if [ "$relative_target" = "$DOTFILES_APPLY_PROBE_TARGET" ]; then
            next_target="${HOME}/${DOTFILES_APPLY_PROBE_NEXT_TARGET}"
            mkdir -p "$(dirname -- "$next_target")"
            rm -f -- "$next_target"
            ln -s /dev/null "$next_target"
        fi
        ;;
    swap-next-directory)
        run_real_apply "$@" || exit $?
        if [ "$relative_target" = "$DOTFILES_APPLY_PROBE_TARGET" ]; then
            next_target="${HOME}/${DOTFILES_APPLY_PROBE_NEXT_TARGET}"
            rm -f -- "$next_target"
            mkdir -p "$next_target"
        fi
        ;;
    term-target)
        if [ "$relative_target" = "$DOTFILES_APPLY_PROBE_TARGET" ]; then
            kill -TERM "$PPID"
            sleep 1
            exit 143
        fi
        run_real_apply "$@"
        ;;
    *)
        exit 98
        ;;
esac
