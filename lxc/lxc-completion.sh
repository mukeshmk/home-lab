#!/usr/bin/env bash

# Bash completion for 'lxc'

_lxc_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="add update clean trim edit start stop restart"

    if [[ ${COMP_CWORD} -eq 1 ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi

    case "${prev}" in
        add)
            local add_opts="docker debian"
            COMPREPLY=( $(compgen -W "${add_opts}" -- "${cur}") )
            return 0
            ;;
        edit|start|stop|restart)
            local lxc_ids=""
            if [ -d "/etc/pve/lxc" ]; then
                # Get LXC IDs from the config files in /etc/pve/lxc/
                lxc_ids=$(find /etc/pve/lxc -maxdepth 1 -name "*.conf" 2>/dev/null | sed 's|.*/||; s|\.conf$||')
            fi
            COMPREPLY=( $(compgen -W "${lxc_ids}" -- "${cur}") )
            return 0
            ;;
    esac
}
complete -F _lxc_completion lxc
