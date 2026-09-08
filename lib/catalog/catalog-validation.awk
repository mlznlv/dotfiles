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
        if (module_schema[id] != "1") {
            fail("module " id " schema must be 1")
        }
        if (module_keys[id] != expected_module_keys && module_keys[id] != expected_module_keys_home && module_keys[id] != expected_module_keys_prerequisites && module_keys[id] != expected_module_keys_full) {
            fail("module " id " contains unsupported fields or tables")
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
        validate_commands(module_macos_commands[id], "module " id " macos commands")
        validate_applications(module_macos_applications[id], "module " id " macos applications")
        validate_artifacts(module_macos_artifacts[id], "module " id " macos artifacts")
        validate_commands(module_debian_commands[id], "module " id " debian commands")
        validate_applications(module_debian_applications[id], "module " id " debian applications")
        validate_artifacts(module_debian_artifacts[id], "module " id " debian artifacts")
        validate_sources(module_sources[id], "module " id " chezmoi sources")
        if ((module_macos_commands[id] != "-" || module_macos_applications[id] != "-" || module_macos_artifacts[id] != "-") && !list_contains(module_platforms[id], "macos")) {
            fail("module " id " declares macos prerequisites without macos support")
        }
        if ((module_debian_commands[id] != "-" || module_debian_applications[id] != "-" || module_debian_artifacts[id] != "-") && !list_contains(module_platforms[id], "debian")) {
            fail("module " id " declares debian prerequisites without debian support")
        }
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
