BEGIN {
    FS = "\t"
    OFS = "\t"
    expected_root_keys = "modules,profiles,schema"
    expected_module_keys = "conflicts,depends,docs,exclusive_group,id,name,platforms,schema,summary"
    expected_profile_keys = "docs,id,modules,name,platforms,schema,summary"
}

function fail(message) {
    print "error: " message > "/dev/stderr"
    errors++
}

function valid_id(id) {
    return id ~ /^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$/
}

function split_list(value, result) {
    if (value == "-" || value == "") {
        return 0
    }
    return split(value, result, ",")
}

function list_contains(value, wanted,    values, count, i) {
    count = split_list(value, values)
    for (i = 1; i <= count; i++) {
        if (values[i] == wanted) {
            return 1
        }
    }
    return 0
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

function expected_docs(kind, id,    parts, count, i, filename, directory) {
    count = split(id, parts, ".")
    directory = parts[1]
    filename = parts[2]
    for (i = 3; i <= count; i++) {
        filename = filename "-" parts[i]
    }
    return "docs/" kind "/" directory "/" filename ".md"
}

function sort_values(values, count,    left, right, temporary) {
    for (left = 1; left <= count; left++) {
        for (right = left + 1; right <= count; right++) {
            if (values[right] < values[left]) {
                temporary = values[left]
                values[left] = values[right]
                values[right] = temporary
            }
        }
    }
}

function visit_dependency(id,    dependencies, count, i) {
    if (dependency_mark[id] == 1) {
        fail("dependency cycle includes " id)
        return
    }
    if (dependency_mark[id] == 2) {
        return
    }
    dependency_mark[id] = 1
    count = split_list(module_depends[id], dependencies)
    sort_values(dependencies, count)
    for (i = 1; i <= count; i++) {
        if (module_exists[dependencies[i]]) {
            visit_dependency(dependencies[i])
        }
    }
    dependency_mark[id] = 2
}

function validate_catalog(    i, id, values, count, item, platform_values, platform_count, platform_index, dependency_values, dependency_count, dependency_index) {
    if (root_count != 1) {
        fail("catalog must contain exactly one root record")
    }
    if (root_schema != "1") {
        fail("catalog schema must be 1")
    }
    if (root_keys != expected_root_keys) {
        fail("catalog root fields must be " expected_root_keys)
    }

    for (i = 1; i <= module_count; i++) {
        id = module_order[i]
        if (!valid_id(id)) {
            fail("invalid module identifier " id)
        }
        if (module_declared_id[id] != id) {
            fail("module key and id differ for " id)
        }
        if (module_keys[id] != expected_module_keys) {
            fail("module " id " fields must be " expected_module_keys)
        }
        if (module_schema[id] != "1") {
            fail("module " id " schema must be 1")
        }
        if (module_name[id] == "" || module_summary[id] == "") {
            fail("module " id " requires name and summary")
        }
        if (module_docs[id] != expected_docs("modules", id)) {
            fail("module " id " documentation path must be " expected_docs("modules", id))
        }
        validate_platforms(module_platforms[id], "module " id " platforms")
        validate_list(module_depends[id], "module " id " dependencies", 0)
        validate_list(module_conflicts[id], "module " id " conflicts", 0)
        if (module_group[id] != "-" && !valid_id(module_group[id])) {
            fail("module " id " has invalid exclusive group " module_group[id])
        }

        count = split_list(module_depends[id], values)
        for (item = 1; item <= count; item++) {
            if (!module_exists[values[item]]) {
                fail("module " id " depends on unknown module " values[item])
            }
            if (values[item] == id) {
                fail("module " id " cannot depend on itself")
            }
            if (list_contains(module_conflicts[id], values[item])) {
                fail("module " id " both depends on and conflicts with " values[item])
            }
        }

        count = split_list(module_conflicts[id], values)
        for (item = 1; item <= count; item++) {
            if (!module_exists[values[item]]) {
                fail("module " id " conflicts with unknown module " values[item])
            }
            if (values[item] == id) {
                fail("module " id " cannot conflict with itself")
            }
        }

        platform_count = split_list(module_platforms[id], platform_values)
        dependency_count = split_list(module_depends[id], dependency_values)
        for (platform_index = 1; platform_index <= platform_count; platform_index++) {
            for (dependency_index = 1; dependency_index <= dependency_count; dependency_index++) {
                if (module_exists[dependency_values[dependency_index]] && !list_contains(module_platforms[dependency_values[dependency_index]], platform_values[platform_index])) {
                    fail("module " id " supports " platform_values[platform_index] " but dependency " dependency_values[dependency_index] " does not")
                }
            }
        }
    }

    for (i = 1; i <= module_count; i++) {
        visit_dependency(module_order[i])
    }

    for (i = 1; i <= profile_count; i++) {
        id = profile_order[i]
        if (!valid_id(id)) {
            fail("invalid profile identifier " id)
        }
        if (profile_declared_id[id] != id) {
            fail("profile key and id differ for " id)
        }
        if (profile_keys[id] != expected_profile_keys) {
            fail("profile " id " fields must be " expected_profile_keys)
        }
        if (profile_schema[id] != "1") {
            fail("profile " id " schema must be 1")
        }
        if (profile_name[id] == "" || profile_summary[id] == "") {
            fail("profile " id " requires name and summary")
        }
        if (profile_docs[id] != expected_docs("profiles", id)) {
            fail("profile " id " documentation path must be " expected_docs("profiles", id))
        }
        validate_platforms(profile_platforms[id], "profile " id " platforms")
        validate_list(profile_modules[id], "profile " id " modules", 1)

        count = split_list(profile_modules[id], values)
        for (item = 1; item <= count; item++) {
            if (!module_exists[values[item]]) {
                fail("profile " id " contains unknown module " values[item])
            }
        }

        platform_count = split_list(profile_platforms[id], platform_values)
        for (platform_index = 1; platform_index <= platform_count; platform_index++) {
            for (item = 1; item <= count; item++) {
                if (module_exists[values[item]] && !list_contains(module_platforms[values[item]], platform_values[platform_index])) {
                    fail("profile " id " supports " platform_values[platform_index] " but module " values[item] " does not")
                }
            }
        }
    }
}

function add_resolved(id,    dependencies, count, i) {
    if (!module_exists[id]) {
        fail("unknown module " id)
        return
    }
    if (!list_contains(module_platforms[id], platform)) {
        fail("module " id " does not support platform " platform)
        return
    }
    if (resolve_mark[id] == 2) {
        return
    }
    if (resolve_mark[id] == 1) {
        fail("dependency cycle includes " id)
        return
    }

    resolve_mark[id] = 1
    count = split_list(module_depends[id], dependencies)
    sort_values(dependencies, count)
    for (i = 1; i <= count; i++) {
        add_resolved(dependencies[i])
    }
    resolve_mark[id] = 2
    if (!chosen[id]) {
        chosen[id] = 1
        resolved_order[++resolved_count] = id
    }
}

function resolve_modules(    roots, root_count_local, additions, addition_count, i, id, conflicts, conflict_count, conflict_index, group) {
    if (profile != "") {
        if (!profile_exists[profile]) {
            fail("unknown profile " profile)
            return
        }
        if (!list_contains(profile_platforms[profile], platform)) {
            fail("profile " profile " does not support platform " platform)
            return
        }
        base_selection = profile_modules[profile]
    }

    validate_list(base_selection, "base selection", 1)
    validate_list(additional, "additional modules", 0)
    if (errors) {
        return
    }

    root_count_local = split_list(base_selection, roots)
    for (i = 1; i <= root_count_local; i++) {
        add_resolved(roots[i])
    }
    addition_count = split_list(additional, additions)
    for (i = 1; i <= addition_count; i++) {
        add_resolved(additions[i])
    }
    if (errors) {
        return
    }

    for (i = 1; i <= resolved_count; i++) {
        id = resolved_order[i]
        conflict_count = split_list(module_conflicts[id], conflicts)
        for (conflict_index = 1; conflict_index <= conflict_count; conflict_index++) {
            if (chosen[conflicts[conflict_index]]) {
                fail("module " id " conflicts with " conflicts[conflict_index])
            }
        }
        group = module_group[id]
        if (group != "-") {
            if (group_owner[group] != "" && group_owner[group] != id) {
                fail("modules " group_owner[group] " and " id " share exclusive group " group)
            } else {
                group_owner[group] = id
            }
        }
    }

    if (!errors) {
        for (i = 1; i <= resolved_count; i++) {
            print resolved_order[i]
        }
    }
}

$0 == "" {
    next
}

$1 == "C" {
    if (NF != 3) {
        fail("malformed catalog root record")
        next
    }
    root_count++
    root_schema = $2
    root_keys = $3
    next
}

$1 == "M" {
    if (NF != 12) {
        fail("malformed module record")
        next
    }
    if (module_exists[$2]) {
        fail("duplicate module " $2)
        next
    }
    module_exists[$2] = 1
    module_order[++module_count] = $2
    module_declared_id[$2] = $4
    module_keys[$2] = $3
    module_schema[$2] = $5
    module_name[$2] = $6
    module_summary[$2] = $7
    module_docs[$2] = $8
    module_platforms[$2] = $9
    module_depends[$2] = $10
    module_conflicts[$2] = $11
    module_group[$2] = $12
    next
}

$1 == "P" {
    if (NF != 10) {
        fail("malformed profile record")
        next
    }
    if (profile_exists[$2]) {
        fail("duplicate profile " $2)
        next
    }
    profile_exists[$2] = 1
    profile_order[++profile_count] = $2
    profile_declared_id[$2] = $4
    profile_keys[$2] = $3
    profile_schema[$2] = $5
    profile_name[$2] = $6
    profile_summary[$2] = $7
    profile_docs[$2] = $8
    profile_platforms[$2] = $9
    profile_modules[$2] = $10
    next
}

{
    fail("unknown catalog record type " $1)
}

END {
    validate_catalog()
    if (errors) {
        exit 3
    }

    if (action == "validate") {
        print "catalog valid: " module_count " modules, " profile_count " profiles"
    } else if (action == "list_modules") {
        for (i = 1; i <= module_count; i++) {
            id = module_order[i]
            if (show_all == "1" || list_contains(module_platforms[id], platform)) {
                print id, module_name[id], module_summary[id]
            }
        }
    } else if (action == "show_module") {
        if (!module_exists[target_id]) {
            fail("unknown module " target_id)
        } else {
            print "id: " target_id
            print "name: " module_name[target_id]
            print "summary: " module_summary[target_id]
            print "platforms: " module_platforms[target_id]
            print "depends: " module_depends[target_id]
            print "conflicts: " module_conflicts[target_id]
            print "exclusive group: " module_group[target_id]
            print "docs: " module_docs[target_id]
        }
    } else if (action == "list_profiles") {
        for (i = 1; i <= profile_count; i++) {
            id = profile_order[i]
            if (show_all == "1" || list_contains(profile_platforms[id], platform)) {
                print id, profile_name[id], profile_summary[id]
            }
        }
    } else if (action == "show_profile") {
        if (!profile_exists[target_id]) {
            fail("unknown profile " target_id)
        } else {
            print "id: " target_id
            print "name: " profile_name[target_id]
            print "summary: " profile_summary[target_id]
            print "platforms: " profile_platforms[target_id]
            print "modules: " profile_modules[target_id]
            print "docs: " profile_docs[target_id]
        }
    } else if (action == "resolve") {
        resolve_modules()
    } else {
        fail("unknown catalog action " action)
    }

    if (errors) {
        exit 3
    }
}
