function print_prerequisites(    i, id, commands, applications, artifacts, values, count, item) {
    resolve_modules(0)
    if (errors) return
    for (i = 1; i <= resolved_count; i++) {
        id = resolved_order[i]
        if (platform == "macos") {
            commands = module_macos_commands[id]
            applications = module_macos_applications[id]
            artifacts = module_macos_artifacts[id]
        } else {
            commands = module_debian_commands[id]
            applications = module_debian_applications[id]
            artifacts = module_debian_artifacts[id]
        }
        count = split_list(commands, values)
        for (item = 1; item <= count; item++) print id, "command", values[item]
        delete values
        count = split_list(applications, values)
        for (item = 1; item <= count; item++) print id, "application", values[item]
        delete values
        count = split_list(artifacts, values)
        for (item = 1; item <= count; item++) print id, "artifact", values[item]
        delete values
    }
}

function print_render_inputs(    i, id, values, count, item, source_count, source_module, source_value, source_target, left, right, temporary) {
    resolve_modules(0)
    if (errors) return

    for (i = 1; i <= resolved_count; i++) {
        print "module", resolved_order[i]
    }

    for (i = 1; i <= resolved_count; i++) {
        id = resolved_order[i]
        count = split_list(module_sources[id], values)
        for (item = 1; item <= count; item++) {
            source_count++
            source_module[source_count] = id
            source_value[source_count] = values[item]
            source_target[source_count] = normalize_source(values[item])
        }
        delete values
    }

    for (left = 1; left <= source_count; left++) {
        for (right = left + 1; right <= source_count; right++) {
            if (source_target[right] < source_target[left] ||
                (source_target[right] == source_target[left] && source_module[right] < source_module[left]) ||
                (source_target[right] == source_target[left] && source_module[right] == source_module[left] && source_value[right] < source_value[left])) {
                temporary = source_module[left]
                source_module[left] = source_module[right]
                source_module[right] = temporary
                temporary = source_value[left]
                source_value[left] = source_value[right]
                source_value[right] = temporary
                temporary = source_target[left]
                source_target[left] = source_target[right]
                source_target[right] = temporary
            }
        }
    }

    for (i = 1; i <= source_count; i++) {
        print "source", source_module[i], source_value[i], source_target[i]
    }
}
