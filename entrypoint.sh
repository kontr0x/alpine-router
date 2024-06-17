#!/bin/sh

__enable_ip_forward() {
    echo 1 | tee -a /proc/sys/net/ipv4/ip_forward &>/dev/null
    if [ $(cat /proc/sys/net/ipv4/ip_forward) == 0 ]
    then
        echo "WARNING: IPv4 forwarding not enabled successfully, this might lead to unwanted behavior"
    fi
}

__apply_fw_rules() {
    if [ -f /fwrules.sh ]; then
        /bin/sh /fwrules.sh
    fi
}

__run_custom_commands() {
    if [ -f /commands.sh ]; then
        /bin/sh /commands.sh
    fi
}

__enable_ip_forward
__apply_fw_rules
__run_custom_commands

exec /bin/sh
