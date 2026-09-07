function validate_unique_values(value, label,    values, count, i, previous) {
    count = split_list(value, values)
    for (i = 1; i <= count; i++) {
        for (previous = 1; previous < i; previous++) {
            if (values[previous] == values[i]) {
                fail(label " contains duplicate identifier " values[i])
            }
        }
    }
}

function validate_commands(value, label,    values, count, i) {
    count = split_list(value, values)
    for (i = 1; i <= count; i++) {
        if (values[i] !~ /^[A-Za-z0-9][A-Za-z0-9._+-]*$/) {
            fail(label " contains unsafe command identifier " values[i])
        }
    }
    validate_unique_values(value, label)
}

function validate_applications(value, label,    values, count, i) {
    count = split_list(value, values)
    for (i = 1; i <= count; i++) {
        if (values[i] !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) {
            fail(label " contains unsafe application identifier " values[i])
        }
    }
    validate_unique_values(value, label)
}

function validate_artifacts(value, label,    values, count, i, separator, root, relative, segments, segment_count, segment_index) {
    count = split_list(value, values)
    for (i = 1; i <= count; i++) {
        separator = index(values[i], ":")
        if (separator == 0) {
            fail(label " contains artifact locator without root " values[i])
            continue
        }
        root = substr(values[i], 1, separator - 1)
        relative = substr(values[i], separator + 1)
        if (root != "share") {
            fail(label " contains unknown artifact root " root)
            continue
        }
        if (relative == "" || relative ~ /^\// || relative !~ /^[A-Za-z0-9._+@\/-]+$/) {
            fail(label " contains unsafe artifact locator " values[i])
            continue
        }
        segment_count = split(relative, segments, "/")
        for (segment_index = 1; segment_index <= segment_count; segment_index++) {
            if (segments[segment_index] == "" || segments[segment_index] == "." || segments[segment_index] == "..") {
                fail(label " contains unsafe artifact locator " values[i])
                break
            }
        }
    }
    validate_unique_values(value, label)
}

function validate_list(value, label, require_value,    values, count, i, previous) {
    count = split_list(value, values)
    if (require_value && count == 0) {
        fail(label " must not be empty")
        return
    }
    for (i = 1; i <= count; i++) {
        if (!valid_id(values[i])) {
            fail(label " contains invalid identifier " values[i])
        }
        for (previous = 1; previous < i; previous++) {
            if (values[previous] == values[i]) {
                fail(label " contains duplicate identifier " values[i])
            }
        }
    }
}

function validate_platforms(value, label,    values, count, i, previous) {
    count = split_list(value, values)
    if (count == 0) {
        fail(label " must declare at least one platform")
        return
    }
    for (i = 1; i <= count; i++) {
        if (values[i] != "macos" && values[i] != "debian") {
            fail(label " contains unsupported platform " values[i])
        }
        for (previous = 1; previous < i; previous++) {
            if (values[previous] == values[i]) {
                fail(label " contains duplicate platform " values[i])
            }
        }
    }
}

function normalize_source(source,    segments, count, i, segment, target) {
    sub(/^home\//, "", source)
    sub(/\.tmpl$/, "", source)
    count = split(source, segments, "/")
    for (i = 1; i <= count; i++) {
        segment = segments[i]
        sub(/^dot_/, ".", segment)
        target = target (i == 1 ? "" : "/") segment
    }
    return target
}

function validate_sources(value, label,    values, count, i, previous, parts, part_count, part_index, segment, target) {
    count = split_list(value, values)
    for (i = 1; i <= count; i++) {
        if (values[i] !~ /^home\// || values[i] ~ /^\// || values[i] ~ /\/$/ || values[i] ~ /\/\.?\.?\// || values[i] ~ /\/(\.|\.\.)$/) {
            fail(label " contains unsafe chezmoi source " values[i])
            continue
        }
        part_count = split(values[i], parts, "/")
        if (part_count < 2) {
            fail(label " contains empty chezmoi target " values[i])
            continue
        }
        for (part_index = 2; part_index <= part_count; part_index++) {
            segment = parts[part_index]
            if (segment == "" || segment == "." || segment == ".." || segment ~ /^\.chezmoi/ || segment ~ /^(exact_|modify_|remove_|run_|symlink_|private_|encrypted_|create_|executable_|readonly_|empty_|external_|archive_)/ || segment ~ /_(exact|remove|symlink)$/ || (segment ~ /\.tmpl$/ && part_index != part_count)) {
                fail(label " contains unsupported chezmoi entry " values[i])
            }
        }
        target = normalize_source(values[i])
        if (target == "" || target == ".") {
            fail(label " contains empty chezmoi target " values[i])
        }
        for (previous = 1; previous < i; previous++) {
            if (values[previous] == values[i]) {
                fail(label " contains duplicate chezmoi source " values[i])
            }
        }
    }
}

function expected_docs(kind, id,    parts, count, i, filename, directory) {
    count = split(id, parts, ".")
    directory = parts[1]
    filename = parts[2]
    for (i = 3; i <= count; i++) {
        filename = filename "-" parts[i]
    }

    if (kind == "modules" && (id == "shell.zsh" || index(id, "shell.zsh.") == 1)) {
        directory = "shell/zsh"
        filename = (id == "shell.zsh" ? "zsh" : substr(id, length("shell.zsh.") + 1))
        gsub(/\./, "-", filename)
    }
    return "docs/" kind "/" directory "/" filename ".md"
}
