production_shell_paths() {
    local repository_root=$1

    printf '%s\n' "${repository_root%/}/bin/dotfiles"
    find "${repository_root%/}/lib" -type f -name '*.sh' -print | LC_ALL=C sort
}

test_shell_paths() {
    local repository_root=$1

    find "${repository_root%/}/tests" -type f -name '*.sh' -print | LC_ALL=C sort
}

maintained_file_paths() {
    local repository_root=$1
    local relative

    for relative in .chezmoidata .github/workflows bin home lib scripts tests; do
        [ -d "${repository_root%/}/$relative" ] || continue
        find "${repository_root%/}/$relative" -type f -print
    done | LC_ALL=C sort
}

repository_relative_path() {
    local repository_root=$1
    local file=$2
    printf '%s\n' "${file#"${repository_root%/}/"}"
}

physical_line_count() {
    LC_ALL=C awk 'END { print NR + 0 }' "$1"
}

maintainability_diagnostic() {
    printf 'error: %s\n' "$1" >&2
}

decomposed_test_suites() {
    printf '%s\n' \
        config-state config-inspection config-interactive config-consumption apply maintainability
}

test_file_mode() {
    if stat -f '%Lp' "$1" >/dev/null 2>&1; then
        stat -f '%Lp' "$1"
    else
        stat -c '%a' "$1"
    fi
}
