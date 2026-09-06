BEGIN {
    FS = "\t"
    OFS = "\t"
    expected_root_keys = "modules,profiles,schema"
    expected_module_keys = "conflicts,depends,docs,exclusive_group,id,name,platforms,schema,summary"
    expected_module_keys_home = "conflicts,depends,docs,exclusive_group,home,id,name,platforms,schema,summary"
    expected_module_keys_prerequisites = "conflicts,depends,docs,exclusive_group,id,name,platforms,prerequisites,schema,summary"
    expected_module_keys_full = "conflicts,depends,docs,exclusive_group,home,id,name,platforms,prerequisites,schema,summary"
    expected_profile_keys = "docs,id,modules,name,platforms,schema,summary"
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
    if (NF != 19) {
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
    module_macos_commands[$2] = $13
    module_macos_applications[$2] = $14
    module_macos_artifacts[$2] = $15
    module_debian_commands[$2] = $16
    module_debian_applications[$2] = $17
    module_debian_artifacts[$2] = $18
    module_sources[$2] = $19
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
        print "catalog valid: " count_label(module_count + 0, "module") ", " count_label(profile_count + 0, "profile")
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
        resolve_modules(1)
    } else if (action == "prerequisites") {
        print_prerequisites()
    } else if (action == "render_inputs") {
        print_render_inputs()
    } else {
        fail("unknown catalog action " action)
    }

    if (errors) {
        exit 3
    }
}
