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

function resolve_modules(emit_modules,    roots, root_count_local, additions, addition_count, i, id, conflicts, conflict_count, conflict_index, group) {
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
        check_chezmoi_ownership(id, module_sources[id])
    }

    if (!errors && emit_modules) {
        for (i = 1; i <= resolved_count; i++) {
            print resolved_order[i]
        }
    }
}

function claim_ownership(module, key, source) {
    if (ownership_module[key] != "") {
        if (source != "") {
            fail("duplicate ownership key " key " declared by modules " ownership_module[key] " and " module " from " ownership_source[key] " and " source)
        } else {
            fail("duplicate ownership key " key " declared by modules " ownership_module[key] " and " module)
        }
    } else {
        ownership_module[key] = module
        ownership_source[key] = source
    }
}

function check_chezmoi_ownership(module, value,    values, count, i, target) {
    count = split_list(value, values)
    for (i = 1; i <= count; i++) {
        target = normalize_source(values[i])
        claim_ownership(module, "chezmoi:target:" target, values[i])
    }
}
