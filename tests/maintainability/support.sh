maintainability_allocate_root() {
    TEST_PARENT=${TMPDIR:-/tmp}
    TEST_PARENT=$(CDPATH= cd -- "$TEST_PARENT" && pwd -P)
    TEST_ROOT=$(mktemp -d "${TEST_PARENT%/}/dotfiles-maintainability-tests.XXXXXX")
}

cleanup() {
    rm -rf -- "$TEST_ROOT"
}

maintainability_initialize() {
    # shellcheck source=../../scripts/check-maintainability.sh
    source "${PROJECT_ROOT}/scripts/check-maintainability.sh" || exit $?
    failures=0
    checks=0
    STATUS=0
    STDOUT=
    STDERR=
    OUTPUT=
}

test_initialization_interruptions_cleanup() (
    local repository_root=$1 work_root=$2 suite fixture runner support instrumented
    local marker process_id attempts allocated_root

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

pass() {
    checks=$((checks + 1))
    printf 'ok - %s\n' "$1"
}

fail() {
    checks=$((checks + 1))
    failures=$((failures + 1))
    printf 'not ok - %s\n' "$1"
    printf '  status: %s\n' "$STATUS"
    printf '  output: %s\n' "$OUTPUT"
}

check_status() {
    local name=$1
    local expected=$2
    if [ "$STATUS" -eq "$expected" ]; then pass "$name"; else fail "$name"; fi
}

check_equal() {
    local name=$1
    local actual=$2
    local expected=$3
    if [ "$actual" = "$expected" ]; then
        pass "$name"
    else
        STATUS=1
        OUTPUT="expected: ${expected}; actual: ${actual}"
        fail "$name"
    fi
}

check_contains() {
    local name=$1
    local expected=$2
    case "$OUTPUT" in *"$expected"*) pass "$name" ;; *) STATUS=1; fail "$name" ;; esac
}

check_not_contains() {
    local name=$1
    local rejected=$2
    case "$OUTPUT" in *"$rejected"*) STATUS=1; fail "$name" ;; *) pass "$name" ;; esac
}

run_command() {
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"

    "$@" > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
}

run_from_directory() {
    local directory=$1
    shift
    local stdout_file="${TEST_ROOT}/stdout"
    local stderr_file="${TEST_ROOT}/stderr"

    (
        CDPATH= cd -- "$directory" || exit 1
        "$@"
    ) > "$stdout_file" 2> "$stderr_file"
    STATUS=$?
    STDOUT=$(< "$stdout_file")
    STDERR=$(< "$stderr_file")
    OUTPUT="${STDOUT}${STDOUT:+$'\n'}${STDERR}"
}

source_is_side_effect_free() (
    local target=$1
    local working_directory=$2
    local tag=$3
    local stdout_file="${TEST_ROOT}/${tag}.stdout"
    local stderr_file="${TEST_ROOT}/${tag}.stderr"
    local before_pwd before_ifs before_umask before_options before_option_state before_traps
    local before_tree after_tree source_status

    : > "$stdout_file"
    : > "$stderr_file"
    CDPATH= cd -- "$working_directory" || exit 1
    before_pwd=$PWD
    before_ifs=$IFS
    before_umask=$(umask)
    before_options=$-
    before_option_state=$(set +o)
    before_traps=$(trap -p)
    before_tree=$(find . -print | LC_ALL=C sort)
    # shellcheck disable=SC1090
    source "$target" > "$stdout_file" 2> "$stderr_file"
    source_status=$?
    after_tree=$(find . -print | LC_ALL=C sort)
    [ "$source_status" -eq 0 ] && [ ! -s "$stdout_file" ] && [ ! -s "$stderr_file" ] &&
        [ "$PWD" = "$before_pwd" ] && [ "$IFS" = "$before_ifs" ] &&
        [ "$(umask)" = "$before_umask" ] && [ "$-" = "$before_options" ] &&
        [ "$(set +o)" = "$before_option_state" ] && [ "$(trap -p)" = "$before_traps" ] &&
        [ "$after_tree" = "$before_tree" ]
)

make_test_layout_fixture() {
    local root=$1 suite
    mkdir -p "$root/tests"
    while IFS= read -r suite; do
        cp "${PROJECT_ROOT}/tests/${suite}.sh" "$root/tests/"
        cp -R "${PROJECT_ROOT}/tests/${suite}" "$root/tests/"
    done < <(decomposed_test_suites)
}

check_layout_rejection() {
    local name=$1 root=$2 diagnostic=$3 output
    output=$(check_test_suite_layouts "$root" 2>&1)
    STATUS=$?
    OUTPUT=$output
    check_status "$name" 1
    check_contains "${name} has a focused diagnostic" "$diagnostic"
}

output_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{ print $1 }'
    else
        shasum -a 256 | awk '{ print $1 }'
    fi
}

expected_suite_hash() {
    case "$1" in
        config-state) printf '%s\n' 5dcb2870100b997e0884dc8f05f1af3043a2b418ccf862eb730c885ad20db3c4 ;;
        config-interactive) printf '%s\n' 8cb78b7d7753b6996723ed8a71516b2772902345d8fe8703626c4d194ea56304 ;;
        config-consumption) printf '%s\n' 6c257b324b5da0e689b8ad28abe193e718305869b61d539d09acbb756e501445 ;;
        config-inspection) printf '%s\n' b39c32153a7e90ac10224dff3de87caa630ba2a71b04baceff3836efc4982ac8 ;;
        apply) printf '%s\n' b57c9fb81fc2b06fef2c42fe734dbddeaa275e9478f7a2b3a7d9a6b8ab2d9254 ;;
    esac
}
