#!/usr/bin/env bash

test_initialization_interruptions_cleanup() (
    local repository_root=$1
    local work_root=$2
    local suite
    local fixture
    local runner
    local support
    local instrumented
    local marker
    local process_id
    local attempts
    local allocated_root

    for suite in config-state config-interactive config-consumption config-inspection apply; do
        fixture="${work_root}/${suite}"
        runner="${fixture}/tests/${suite}.sh"
        support="${fixture}/tests/${suite}/support.sh"
        instrumented="${support}.instrumented"
        marker="${fixture}/allocated-root"
        mkdir -p "${fixture}/tests/${suite}" "${fixture}/tmp"
        cp "${repository_root}/tests/${suite}.sh" "$runner"
        cp "${repository_root}/tests/${suite}/support.sh" "$support"
        awk '
            !injected && /^[a-zA-Z_][a-zA-Z0-9_]*_initialize\(\) \{$/ {
                print
                print "    printf \"%s\\n\" \"$TEST_ROOT\" > \"$DOTFILES_TEST_INIT_MARKER\""
                print "    while :; do :; done"
                injected=1
                next
            }
            { print }
            END { if (!injected) exit 1 }
        ' "$support" > "$instrumented" || return 1
        mv "$instrumented" "$support"

        DOTFILES_TEST_INIT_MARKER="$marker" TMPDIR="${fixture}/tmp" \
            bash "$runner" > "${fixture}/stdout" 2> "${fixture}/stderr" &
        process_id=$!
        attempts=0
        while [ ! -s "$marker" ] && kill -0 "$process_id" 2>/dev/null &&
            [ "$attempts" -lt 200 ]; do
            sleep 0.01
            attempts=$((attempts + 1))
        done
        if [ ! -s "$marker" ]; then
            kill -TERM "$process_id" 2>/dev/null
            wait "$process_id" 2>/dev/null
            printf 'initialization interruption marker was not created: tests/%s.sh\n' "$suite" >&2
            return 1
        fi
        IFS= read -r allocated_root < "$marker"
        case "$allocated_root" in
            "${fixture}/tmp/"*) ;;
            *)
                kill -TERM "$process_id" 2>/dev/null
                wait "$process_id" 2>/dev/null
                printf 'initialization root escaped its fixture: tests/%s.sh\n' "$suite" >&2
                return 1
                ;;
        esac
        kill -TERM "$process_id" 2>/dev/null
        wait "$process_id" 2>/dev/null
        if [ -e "$allocated_root" ]; then
            printf 'interrupted initialization left test debris: tests/%s.sh\n' "$suite" >&2
            return 1
        fi
    done
)
