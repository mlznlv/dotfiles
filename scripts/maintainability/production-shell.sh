check_production_modes() {
    local repository_root=$1 relative file failed=0

    for relative in bin/dotfiles scripts/check.sh scripts/check-maintainability.sh; do
        if [ ! -x "${repository_root%/}/$relative" ]; then
            printf 'error: required executable mode is missing: %s\n' "$relative" >&2
            failed=1
        fi
    done
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if [ -x "$file" ]; then
            relative=${file#"${repository_root%/}/"}
            printf 'error: source-only library must not be executable: %s\n' "$relative" >&2
            failed=1
        fi
    done < <(find "${repository_root%/}/lib" -type f -name '*.sh' -print | LC_ALL=C sort)
    [ "$failed" -eq 0 ]
}

check_production_syntax() {
    local repository_root=$1 file relative failed=0

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if ! bash -n "$file" >/dev/null 2>&1; then
            relative=${file#"${repository_root%/}/"}
            printf 'error: production shell syntax is invalid: %s\n' "$relative" >&2
            failed=1
        fi
    done < <(production_shell_paths "$repository_root")
    [ "$failed" -eq 0 ]
}

check_fixed_loaders() {
    local repository_root=$1
    local cli_loader="${repository_root%/}/lib/cli.sh"
    local state_loader="${repository_root%/}/lib/config-state.sh"
    local actual actual_leaf_set expected expected_leaf_set source_count relative leaf failed=0

    expected='cli/common.sh
cli/catalog.sh
cli/selection.sh
cli/config-commands.sh
cli/execution-commands.sh'
    actual=$(sed -n 's#^source "\$DOTFILES_CLI_LOADER_DIR/\([^"]*\.sh\)" || {$#\1#p' "$cli_loader")
    source_count=$(grep -Ec '^[[:space:]]*source[[:space:]]' "$cli_loader" 2>/dev/null || true)
    if [ "$actual" != "$expected" ] || [ "$source_count" -ne 5 ]; then
        printf 'error: fixed CLI loader order or membership is invalid: lib/cli.sh\n' >&2
        failed=1
    fi
    if grep -Eq '^[[:space:]]*(eval|\.)[[:space:]]' "$cli_loader"; then
        printf 'error: dynamic CLI loader syntax is prohibited: lib/cli.sh\n' >&2
        failed=1
    fi
    expected_leaf_set='cli/catalog.sh
cli/common.sh
cli/config-commands.sh
cli/execution-commands.sh
cli/selection.sh'
    actual_leaf_set=$(
        if [ -d "${repository_root%/}/lib/cli" ]; then
            while IFS= read -r leaf; do printf '%s\n' "${leaf#"${repository_root%/}/lib/"}"; done \
                < <(find "${repository_root%/}/lib/cli" -type f -name '*.sh' -print | LC_ALL=C sort)
        fi
    )
    if [ "$actual_leaf_set" != "$expected_leaf_set" ]; then
        printf 'error: fixed CLI loader leaf set is invalid: lib/cli\n' >&2
        failed=1
    fi
    while IFS= read -r relative; do
        leaf="${repository_root%/}/lib/$relative"
        if [ ! -f "$leaf" ]; then
            printf 'error: fixed CLI loader leaf is missing: lib/%s\n' "$relative" >&2
            failed=1
            continue
        fi
        if grep -Eq '^[[:space:]]*(source|\.)[[:space:]].*(DOTFILES_CLI_LOADER_DIR|/cli/|/cli\.sh)' "$leaf"; then
            printf 'error: CLI loader leaf contains a facade or sibling source edge: lib/%s\n' "$relative" >&2
            failed=1
        fi
    done <<< "$expected"

    expected='config-state/schema.sh
config-state/storage.sh
config-state/reader.sh
config-state/lock.sh
config-state/writer.sh'
    actual=$(sed -n 's#^source "\$DOTFILES_CONFIG_STATE_LOADER_DIR/\([^"]*\.sh\)" || {$#\1#p' "$state_loader")
    source_count=$(grep -Ec '^[[:space:]]*source[[:space:]]' "$state_loader" 2>/dev/null || true)
    if [ "$actual" != "$expected" ] || [ "$source_count" -ne 5 ]; then
        printf 'error: fixed config-state loader order or membership is invalid: lib/config-state.sh\n' >&2
        failed=1
    fi
    if grep -Eq '^[[:space:]]*(eval|\.)[[:space:]]' "$state_loader"; then
        printf 'error: dynamic config-state loader syntax is prohibited: lib/config-state.sh\n' >&2
        failed=1
    fi
    expected_leaf_set='config-state/lock.sh
config-state/reader.sh
config-state/schema.sh
config-state/storage.sh
config-state/writer.sh'
    actual_leaf_set=$(
        if [ -d "${repository_root%/}/lib/config-state" ]; then
            while IFS= read -r leaf; do printf '%s\n' "${leaf#"${repository_root%/}/lib/"}"; done \
                < <(find "${repository_root%/}/lib/config-state" -type f -name '*.sh' -print | LC_ALL=C sort)
        fi
    )
    if [ "$actual_leaf_set" != "$expected_leaf_set" ]; then
        printf 'error: fixed config-state loader leaf set is invalid: lib/config-state\n' >&2
        failed=1
    fi
    while IFS= read -r relative; do
        leaf="${repository_root%/}/lib/$relative"
        if [ ! -f "$leaf" ]; then
            printf 'error: fixed config-state loader leaf is missing: lib/%s\n' "$relative" >&2
            failed=1
            continue
        fi
        if grep -Eq '^[[:space:]]*(source|\.)[[:space:]].*(DOTFILES_CONFIG_STATE_LOADER_DIR|/config-state/|/config-state\.sh)' "$leaf"; then
            printf 'error: config-state loader leaf contains a facade or sibling source edge: lib/%s\n' "$relative" >&2
            failed=1
        fi
    done <<< "$expected"
    [ "$failed" -eq 0 ]
}

shell_function_definitions() {
    local repository_root=$1 file relative
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        relative=${file#"${repository_root%/}/"}
        awk -v path="$relative" '
            /^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ {
                name = $0; sub(/\(\).*/, "", name); print name "\t" path
            }
        ' "$file"
    done < <(production_shell_paths "$repository_root")
}

check_duplicate_function_definitions() {
    local repository_root=$1 definitions duplicates duplicate paths failed=0
    definitions=$(shell_function_definitions "$repository_root")
    duplicates=$(printf '%s\n' "$definitions" | awk -F '\t' 'NF == 2 { print $1 }' | LC_ALL=C sort | uniq -d)
    while IFS= read -r duplicate; do
        [ -n "$duplicate" ] || continue
        paths=$(printf '%s\n' "$definitions" | awk -F '\t' -v name="$duplicate" '$1 == name { print $2 }' | paste -sd ',' -)
        printf 'error: duplicate production function %s: %s\n' "$duplicate" "$paths" >&2
        failed=1
    done <<< "$duplicates"
    [ "$failed" -eq 0 ]
}

awk_leaf_contains_functions_only() {
    awk '
        /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
        depth == 0 && /^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([^)]*\)[[:space:]]*\{/ { depth = 1; next }
        depth == 0 { invalid = 1; next }
        {
            line = $0; opens = gsub(/\{/, "{", line); closes = gsub(/\}/, "}", line)
            depth += opens - closes
            if (depth < 0) invalid = 1
        }
        END { exit (invalid || depth != 0) }
    ' "$1"
}

check_catalog_program_loader() {
    local repository_root=$1 loader manifest manifest_lines actual actual_set manifest_set source_count
    local relative leaf definitions duplicates duplicate paths failed=0
    loader="${repository_root%/}/lib/cli/catalog.sh"
    manifest=$(sed -n 's/^    # catalog-program-manifest: //p' "$loader")
    manifest_lines=$(printf '%s\n' $manifest)
    actual=$(sed -n \
        -e 's#^[[:space:]]*-f "\$CATALOG_PROGRAM_DIRECTORY/\([^"]*\.awk\)" \\#catalog/\1#p' \
        -e 's#^[[:space:]]*-f "\$CATALOG_PROGRAM"$#catalog.awk#p' "$loader")
    source_count=$(grep -Ec '^[[:space:]]*-f[[:space:]]' "$loader" 2>/dev/null || true)
    if [ -z "$manifest" ] || [ "$actual" != "$manifest_lines" ] || [ "$source_count" -ne 6 ]; then
        printf 'error: fixed catalog program order or membership is invalid: lib/cli/catalog.sh\n' >&2
        failed=1
    fi
    if [ "$(printf '%s\n' "$manifest_lines" | LC_ALL=C sort | uniq -d)" ]; then
        printf 'error: duplicate fixed catalog program membership: lib/cli/catalog.sh\n' >&2
        failed=1
    fi
    actual_set=$(
        [ ! -f "${repository_root%/}/lib/catalog.awk" ] || printf '%s\n' catalog.awk
        if [ -d "${repository_root%/}/lib/catalog" ]; then
            while IFS= read -r leaf; do printf 'catalog/%s\n' "${leaf#"${repository_root%/}/lib/catalog/"}"; done \
                < <(find "${repository_root%/}/lib/catalog" -type f -print | LC_ALL=C sort)
        fi
    )
    actual_set=$(printf '%s\n' "$actual_set" | LC_ALL=C sort)
    manifest_set=$(printf '%s\n' "$manifest_lines" | LC_ALL=C sort)
    if [ "$actual_set" != "$manifest_set" ]; then
        printf 'error: fixed catalog program leaf set is invalid: lib/catalog\n' >&2
        failed=1
    fi
    definitions=
    while IFS= read -r relative; do
        [ -n "$relative" ] || continue
        leaf="${repository_root%/}/lib/$relative"
        if [ ! -r "$leaf" ]; then
            printf 'error: fixed catalog program leaf is unavailable: lib/%s\n' "$relative" >&2
            failed=1
            continue
        fi
        if [ "$relative" = catalog.awk ]; then
            if grep -Eq '^[[:space:]]*function[[:space:]]' "$leaf"; then
                printf 'error: catalog entry contains a helper function: lib/catalog.awk\n' >&2
                failed=1
            fi
        elif ! awk_leaf_contains_functions_only "$leaf" || grep -Eq '@include|system[[:space:]]*\(' "$leaf"; then
            printf 'error: catalog leaf is not function-only: lib/%s\n' "$relative" >&2
            failed=1
        fi
        definitions="${definitions}$(awk -v path="lib/$relative" '
            /^[[:space:]]*function[[:space:]]+/ {
                name=$0; sub(/^[[:space:]]*function[[:space:]]+/, "", name)
                sub(/[[:space:]({].*$/, "", name); print "\n" name "\t" path
            }
        ' "$leaf")"
    done <<< "$manifest_lines"
    duplicates=$(printf '%s\n' "$definitions" | sed '/^$/d' | awk -F '\t' '{print $1}' | LC_ALL=C sort | uniq -d)
    while IFS= read -r duplicate; do
        [ -n "$duplicate" ] || continue
        paths=$(printf '%s\n' "$definitions" | awk -F '\t' -v name="$duplicate" '$1 == name {print $2}' | paste -sd ',' -)
        printf 'error: duplicate catalog function %s: %s\n' "$duplicate" "$paths" >&2
        failed=1
    done <<< "$duplicates"
    [ "$failed" -eq 0 ]
}

check_maintainability_loader() {
    local repository_root=$1 loader manifest manifest_lines actual manifest_set actual_set relative leaf
    local source_count definitions duplicates duplicate paths failed=0
    loader="${repository_root%/}/scripts/check-maintainability.sh"
    manifest=$(sed -n 's/^# maintainability-module-manifest: //p' "$loader")
    manifest_lines=$(printf '%s\n' $manifest)
    actual=$(sed -n 's#^source "\$MAINTAINABILITY_LOADER_DIR/\([^"]*\.sh\)"$#\1#p' "$loader")
    source_count=$(grep -Ec '^source[[:space:]]' "$loader" 2>/dev/null || true)
    if [ -z "$manifest" ] || [ "$actual" != "$manifest_lines" ] || [ "$source_count" -ne 4 ]; then
        printf 'error: fixed maintainability loader order or membership is invalid: scripts/check-maintainability.sh\n' >&2
        failed=1
    fi
    if [ "$(printf '%s\n' "$manifest_lines" | LC_ALL=C sort | uniq -d)" ]; then
        printf 'error: duplicate fixed maintainability loader membership: scripts/check-maintainability.sh\n' >&2
        failed=1
    fi
    manifest_set=$(printf '%s\n' "$manifest_lines" | LC_ALL=C sort)
    actual_set=$(
        if [ -d "${repository_root%/}/scripts/maintainability" ]; then
            while IFS= read -r leaf; do printf '%s\n' "${leaf#"${repository_root%/}/scripts/maintainability/"}"; done \
                < <(find "${repository_root%/}/scripts/maintainability" -type f -print | LC_ALL=C sort)
        fi
    )
    if [ "$actual_set" != "$manifest_set" ]; then
        printf 'error: fixed maintainability loader leaf set is invalid: scripts/maintainability\n' >&2
        failed=1
    fi
    definitions=
    while IFS= read -r relative; do
        [ -n "$relative" ] || continue
        leaf="${repository_root%/}/scripts/maintainability/$relative"
        if [ ! -r "$leaf" ]; then
            printf 'error: fixed maintainability loader leaf is unavailable: scripts/maintainability/%s\n' "$relative" >&2
            failed=1
            continue
        fi
        if ! shell_leaf_contains_functions_only "$leaf" ||
            grep -Eq '^[[:space:]]*(source|\.|eval)[[:space:]].*(MAINTAINABILITY_LOADER_DIR|MAINTAINABILITY_SCRIPT_DIR|scripts/maintainability/|check-maintainability\.sh)' "$leaf"; then
            printf 'error: maintainability leaf contains an execution or source edge: scripts/maintainability/%s\n' "$relative" >&2
            failed=1
        fi
        definitions="${definitions}$(awk -v path="scripts/maintainability/$relative" '
            /^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ { name=$0; sub(/\(\).*/, "", name); print "\n" name "\t" path }
        ' "$leaf")"
    done <<< "$manifest_lines"
    duplicates=$(printf '%s\n' "$definitions" | sed '/^$/d' | awk -F '\t' '{print $1}' | LC_ALL=C sort | uniq -d)
    while IFS= read -r duplicate; do
        [ -n "$duplicate" ] || continue
        paths=$(printf '%s\n' "$definitions" | awk -F '\t' -v name="$duplicate" '$1 == name {print $2}' | paste -sd ',' -)
        printf 'error: duplicate maintainability function %s: %s\n' "$duplicate" "$paths" >&2
        failed=1
    done <<< "$duplicates"
    [ "$failed" -eq 0 ]
}

shell_leaf_contains_functions_only() {
    awk '
        /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
        !inside && /^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*(\{|\()[[:space:]]*$/ {
            inside = 1
            next
        }
        inside && /^[})][[:space:]]*$/ { inside = 0; next }
        !inside { invalid = 1 }
        END { exit (invalid || inside) }
    ' "$1"
}
