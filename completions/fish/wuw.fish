function __wuw_service_names
    command wuw --list-services 2>/dev/null
end

function __wuw_needs_service
    set -l words (commandline -opc)
    set -e words[1]
    set -l expect_lines 0

    for word in $words
        if test $expect_lines -eq 1
            set expect_lines 0
            continue
        end

        switch $word
            case -n
                set expect_lines 1
            case -h --help --list-services
                return 1
            case '-*'
            case '*'
                return 1
        end
    end

    test $expect_lines -eq 0
end

complete -c wuw -s h -l help -d 'Display usage'
complete -c wuw -l list-services -d 'List discoverable services'
complete -c wuw -s n -x -d 'Number of recent log lines'
complete -c wuw -f -n __wuw_needs_service \
    -a '(__wuw_service_names)' -d 'Service'
