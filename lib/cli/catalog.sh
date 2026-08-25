# Source-only catalog validation, records, discovery, list, and show behavior.

validate_root_catalog() {
    catalog_file="${SOURCE_DIR}/.chezmoidata/catalog.toml"
    if [ ! -f "$catalog_file" ]; then
        printf 'error: missing catalog root %s\n' "$catalog_file" >&2
        return 3
    fi

    awk '
        BEGIN {
            allowed["schema"] = 1
        }
        /^[[:space:]]*$/ || /^[[:space:]]*#/ {
            next
        }
        /^\[dotfiles\]$/ || /^\[dotfiles\.modules\]$/ || /^\[dotfiles\.profiles\]$/ {
            tables[$0]++
            next
        }
        /^[[:space:]]*[a-z_]+[[:space:]]*=/ {
            line = $0
            sub(/^[[:space:]]*/, "", line)
            key = line
            sub(/[[:space:]]*=.*$/, "", key)
            if (!allowed[key]) {
                print "error: unsupported catalog root field " key > "/dev/stderr"
                invalid = 1
            }
            next
        }
        {
            print "error: unsupported catalog root syntax: " $0 > "/dev/stderr"
            invalid = 1
        }
        END {
            if (tables["[dotfiles]"] != 1 || tables["[dotfiles.modules]"] != 1 || tables["[dotfiles.profiles]"] != 1) {
                print "error: catalog root must contain dotfiles, modules, and profiles tables" > "/dev/stderr"
                invalid = 1
            }
            exit invalid
        }
    ' "$catalog_file" || return 3
}
validate_manifest_shape() {
    manifest=$1
    kind=$2

    awk -v kind="$kind" -v manifest="$manifest" '
        BEGIN {
            allowed["schema"] = 1
            allowed["id"] = 1
            allowed["name"] = 1
            allowed["summary"] = 1
            allowed["docs"] = 1
            allowed["platforms"] = 1
            if (kind == "modules") {
                allowed["depends"] = 1
                allowed["conflicts"] = 1
                allowed["exclusive_group"] = 1
            } else {
                allowed["modules"] = 1
            }
            prefix = "[dotfiles." kind ".\""
        }
        /^[[:space:]]*$/ || /^[[:space:]]*#/ {
            next
        }
        index($0, prefix) == 1 && substr($0, length($0) - 1) == "\"]" {
            headers++
            next
        }
        /^[[:space:]]*[a-z_.]+[[:space:]]*=/ {
            line = $0
            sub(/^[[:space:]]*/, "", line)
            key = line
            sub(/[[:space:]]*=.*$/, "", key)
            if (kind == "modules" && (key == "prerequisites.macos.commands" || key == "prerequisites.macos.applications" || key == "prerequisites.macos.artifacts" || key == "prerequisites.debian.commands" || key == "prerequisites.debian.applications" || key == "prerequisites.debian.artifacts" || key == "home.chezmoi.sources")) {
                next
            }
            if (!allowed[key]) {
                print "error: unsupported field " key " in " manifest > "/dev/stderr"
                invalid = 1
            }
            next
        }
        {
            print "error: unsupported manifest syntax in " manifest ": " $0 > "/dev/stderr"
            invalid = 1
        }
        END {
            if (headers != 1) {
                print "error: " manifest " must contain exactly one " kind " table" > "/dev/stderr"
                invalid = 1
            }
            exit invalid
        }
    ' "$manifest" || return 3
}

validate_manifest_layout() {
    kind=$1
    directory="${SOURCE_DIR}/.chezmoidata/${kind}"

    if [ ! -d "$directory" ]; then
        return 0
    fi

    invalid_file=$(find "$directory" -type f ! -name '*.toml' -print -quit)
    if [ -n "$invalid_file" ]; then
        printf 'error: catalog entries must be TOML files: %s\n' "$invalid_file" >&2
        return 3
    fi

    while IFS= read -r manifest; do
        [ -n "$manifest" ] || continue
        validate_manifest_shape "$manifest" "$kind" || return $?

        if [ "$kind" = "modules" ]; then
            table_id=$(sed -n 's/^\[dotfiles\.modules\."\([^"]*\)"\]$/\1/p' "$manifest")
        else
            table_id=$(sed -n 's/^\[dotfiles\.profiles\."\([^"]*\)"\]$/\1/p' "$manifest")
        fi

        table_count=$(printf '%s\n' "$table_id" | awk 'NF { count++ } END { print count + 0 }')
        if [ "$table_count" -ne 1 ]; then
            printf 'error: %s must declare exactly one catalog identifier\n' "$manifest" >&2
            return 3
        fi

    done < <(find "$directory" -type f -name '*.toml' -print | LC_ALL=C sort)

    while IFS= read -r manifest; do
        [ -n "$manifest" ] || continue

        if [ "$kind" = "modules" ]; then
            table_id=$(sed -n 's/^\[dotfiles\.modules\."\([^"]*\)"\]$/\1/p' "$manifest")
        else
            table_id=$(sed -n 's/^\[dotfiles\.profiles\."\([^"]*\)"\]$/\1/p' "$manifest")
        fi

        category=${table_id%%.*}
        remainder=${table_id#*.}
        filename=${remainder//./-}
        relative=${manifest#"${SOURCE_DIR}/"}
        expected=".chezmoidata/${kind}/${category}/${filename}.toml"

        if [ "$kind" = "modules" ]; then
            case "$table_id" in
                shell.zsh)
                    expected=".chezmoidata/modules/shell/zsh/zsh.toml"
                    ;;
                shell.zsh.*)
                    filename=${table_id#shell.zsh.}
                    filename=${filename//./-}
                    expected=".chezmoidata/modules/shell/zsh/${filename}.toml"
                    ;;
            esac
        fi
        if [ "$relative" != "$expected" ]; then
            printf 'error: %s must be stored at %s\n' "$table_id" "$expected" >&2
            return 3
        fi
    done < <(find "$directory" -type f -name '*.toml' -print | LC_ALL=C sort)
}

validate_catalog_layout() {
    validate_root_catalog || return $?
    validate_manifest_layout modules || return $?
    validate_manifest_layout profiles || return $?
}

catalog_records() {
    if ! command -v "$CHEZMOI_BIN" >/dev/null 2>&1; then
        printf 'error: chezmoi is required for catalog commands\n' >&2
        return 4
    fi
    if [ ! -f "$CATALOG_TEMPLATE" ] || [ ! -f "$CATALOG_PROGRAM" ]; then
        printf 'error: catalog implementation files are missing\n' >&2
        return 4
    fi

    "$CHEZMOI_BIN" --no-pager --no-tty --config /dev/null --config-format toml \
        --refresh-externals=never --source "$SOURCE_DIR" \
        execute-template < "$CATALOG_TEMPLATE"
}

run_catalog() {
    action=$1
    platform=${2:-}
    show_all=${3:-0}
    target_id=${4:-}
    profile=${5:-}
    base_selection=${6:-}
    additional=${7:-}

    validate_catalog_layout || return $?
    records=$(catalog_records) || return $?

    printf '%s\n' "$records" | LC_ALL=C awk \
        -v action="$action" \
        -v platform="$platform" \
        -v show_all="$show_all" \
        -v target_id="$target_id" \
        -v profile="$profile" \
        -v base_selection="$base_selection" \
        -v additional="$additional" \
        -f "$CATALOG_PROGRAM"
}

list_command() {
    kind=$1
    shift
    platform=
    show_all=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --all)
                show_all=1
                ;;
            --platform)
                shift
                [ "$#" -gt 0 ] || usage_error "--platform requires a value"
                platform=$1
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *)
                usage_error "unknown option $1"
                ;;
        esac
        shift
    done

    if [ "$show_all" -eq 1 ] && [ -n "$platform" ]; then
        usage_error "--all and --platform cannot be combined"
    fi
    if [ "$show_all" -eq 0 ]; then
        if [ -z "$platform" ]; then
            platform=$(detect_platform) || exit $?
        fi
        validate_platform "$platform" || exit $?
    fi

    if [ "$kind" = "module" ]; then
        run_catalog list_modules "$platform" "$show_all"
    else
        run_catalog list_profiles "$platform" "$show_all"
    fi
}

show_command() {
    kind=$1
    shift
    [ "$#" -eq 1 ] || usage_error "${kind} show requires one identifier"

    if [ "$kind" = "module" ]; then
        run_catalog show_module "" 0 "$1"
    else
        run_catalog show_profile "" 0 "$1"
    fi
}
