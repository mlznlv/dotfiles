function fail(message) {
    print "error: " message > "/dev/stderr"
    errors++
}

function count_label(count, singular) {
    return count " " singular (count == 1 ? "" : "s")
}

function valid_id(id) {
    return id ~ /^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$/
}

function split_list(value, result) {
    if (value == "-" || value == "~" || value == "") {
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
