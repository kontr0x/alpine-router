#!/bin/sh

## Check if the DEBUG variable is set correctly
#
# Check if the DEBUG variable is set to a valid value
if [ ! -z $DEBUG ] && [ $DEBUG != 0 ] && [ $DEBUG != 1 ] && [ "$DEBUG" != "false" ] && [ "$DEBUG" != "true" ]; then
    echo "ERROR: DEBUG variable must be either 0, 1, false or true"
    return
fi
#
# Correct the DEBUG variable if the value is numeric
if [ ! -z $DEBUG ] && [ "$DEBUG" == "false" ]; then
    DEBUG=0
elif [ ! -z $DEBUG ] && [ "$DEBUG" == "true" ]; then
    DEBUG=1
fi

__send_log() {
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    log_level=$1
    log_message=$2

    # Check if the first argument is a valid log level
    if [ "$log_level" != "DEBUG" ] && [ "$log_level" != "INFO" ] && [ "$log_level" != "WARNING" ] && [ "$log_level" != "ERROR" ]; then
        echo "ERROR: Invalid log level"
        return
    fi

    # Check if debug is enabled, when the log level is DEBUG
    if [ "$log_level" == "DEBUG" ] && [ $DEBUG -ne 1 ]; then
        return
    fi

    # Check if the log level is ERROR
    if [ "$log_level" == "ERROR" ]; then
        echo "$timestamp - $log_level: $log_message" 1>&2
        exit 1
    else
        echo "$timestamp - $log_level: $log_message"
    fi
}

__func_wrapper() {
    function=$1
    __send_log "DEBUG" "Calling __func_wrapper -> $function"

    parameter=$2
    if [ "$parameter" != "" ]; then
        # TODO: Add functionality to pass multiple parameters to the function
        __send_log "DEBUG" "Parameter: $parameter"
    fi

    if [ ! -z $function ]; then
        # Call function and pass arguments
        $function $parameter
    fi

    __send_log "DEBUG" "Finished __func_wrapper <- $function"
}

__run_script() {
    script=$1
    if [ -f $script ]; then
        __send_log "INFO" "Running script: $script"
        /bin/sh $script
    fi
}

__enable_ip_forward() {
    echo 1 | tee -a /proc/sys/net/ipv4/ip_forward &>/dev/null
    if [ $(cat /proc/sys/net/ipv4/ip_forward) -eq 1 ]; then
        __send_log "DEBUG" "IPv4 forwarding enabled"
    else
        __send_log "WARNING" "IPv4 forwarding not enabled successfully, this might lead to unwanted behavior"
    fi
}

__apply_tunnel_fw_rules() {
    tunnel_interface=$1

    ## Apply firewall rules for the tunnel interface
    #
    # Allow traffic initiated from VPN to access "the world"
    iptables -t nat -A POSTROUTING -o $tunnel_interface -j MASQUERADE
    # Allow established traffic to pass back and forth
    iptables -A FORWARD -i $tunnel_interface -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    # Forward to the tunnel interface
    iptables -A FORWARD -i eth0 -o $tunnel_interface -j ACCEPT
    # Save rules
    iptables-save &>/dev/null
}

__vpn_established() {
    __send_log "DEBUG" "Calling __vpn_established"
    currentIP=$1
    __send_log "DEBUG" "Current IP: $current_ip"

    ## Check if the VPN connection is up
    #
    count=0
    max_count=10
    while [ "$currentIP" == $(curl -s ifconfig.io) ]
    do
        sleep 1
        count=$((count+1))
        __send_log "DEBUG" "Waiting for VPN connection to establish, remaining seconds: $((max_count-count))"
        if [ $count -eq $max_count ]; then
            break
        fi
    done
    #
    if [ $count -eq $max_count ]; then
        __send_log "ERROR" "VPN connection did not establish after $max_count seconds"
        return 1
    fi
    #
    __send_log "INFO" "VPN connection is up. New IP: $(curl -s ifconfig.io)" 
    return 0

    __send_log "DEBUG" "Finished __vpn_established"
}

__start_openvpn() {
    # Get the current IP
    current_ip=`curl -s ifconfig.io`   

    # Check if the VPN configuration file exists
    if [ ! -f /etc/openvpn/$VPN_CONFIG ]; then
        __send_log "ERROR" "OpenVPN configuration file not found"
        return
    fi

    OPENVPN_AUTH_FILE_OPTS=""
    # Check if openvpn username and password are set to use auth-user-pass
    if [ ! -z $OPENVPN_USER ] && [ ! -z $OPENVPN_PASS ]; then
        __send_log "DEBUG" "Using specified username and password for auth-user-pass"
        OPENVPN_AUTH_FILE="login.conf"
        # Remove " from the username and password and write them to the auth file
        echo $OPENVPN_USER | tr -d '"' > /etc/openvpn/$OPENVPN_AUTH_FILE
        echo $OPENVPN_PASS | tr -d '"' >> /etc/openvpn/$OPENVPN_AUTH_FILE
        OPENVPN_AUTH_FILE_OPTS="--auth-user-pass $(echo $OPENVPN_AUTH_FILE | tr -d '"')"
    elif [ ! -z $OPENVPN_AUTH_FILE ]; then
        __send_log "DEBUG" "Using specified auth file for auth-user-pass"
        OPENVPN_AUTH_FILE_OPTS="--auth-user-pass $(echo $OPENVPN_AUTH_FILE | tr -d '"')"
    fi

    # Remove " from config file
    VPN_CONFIG=$(echo $VPN_CONFIG | tr -d '"')
    OPENVPN_CMD="openvpn --config $VPN_CONFIG $OPENVPN_AUTH_FILE_OPTS"
    if [ $DEBUG -eq 0 ]; then
        # Append the output to /dev/null
        OPENVPN_CMD="$OPENVPN_CMD &>/dev/null"
    fi

    # Start the OpenVPN connection
    __send_log "DEBUG" "Executing: $OPENVPN_CMD"
    cd /etc/openvpn && $OPENVPN_CMD &

    # Check if the VPN connection is up
    __vpn_established $current_ip

    # Set tunnel firewall rules
    VPN_INTERFACE=tun0
    __func_wrapper __apply_tunnel_fw_rules $VPN_INTERFACE
}

__start_wireguard() {
    # Get the current IP
    current_ip=`curl -s ifconfig.io`

    # Check if the VPN configuration file exists
    if [ ! -f /etc/wireguard/$VPN_CONFIG ]; then
        __send_log "ERROR" "Wireguard VPN configuration file not found"
        return
    fi

    # Remove " from config file
    VPN_CONFIG=$(echo $VPN_CONFIG | tr -d '"')
    # Remove tailing ".conf" from the VPN_CONFIG
    VPN_CONFIG=$(echo $VPN_CONFIG | sed 's/\.conf//')
    WIREGUARD_CMD="wg-quick up $VPN_CONFIG"
    if [ $DEBUG -eq 0 ]; then
        # Append the output to /dev/null
        WIREGUARD_CMD="$WIREGUARD_CMD &>/dev/null"
    fi
 
    # Start the Wireguard VPN connection
    __send_log "DEBUG" "Executing: $WIREGUARD_CMD"
    $WIREGUARD_CMD &

    # Check if the VPN connection is up
    __vpn_established $current_ip

    # Set tunnel firewall rules
    VPN_INTERFACE=$VPN_CONFIG
    __func_wrapper __apply_tunnel_fw_rules $VPN_INTERFACE
}

__start_vpn() {
    # Check if the VPN_TYPE and VPN_CONFIG are set
    if [ -z $VPN_TYPE ] && [ -z $VPN_CONFIG ]; then
        __send_log "DEBUG" "No VPN configuration provided"
        return
    fi

    # Check if the VPN_TYPE and VPN_CONFIG are set together
    if [ -z $VPN_TYPE ] && [ ! -z $VPN_CONFIG ] || [ ! -z $VPN_TYPE ] && [ -z $VPN_CONFIG ]; then
        __send_log "ERROR" "VPN_TYPE and VPN_CONFIG must be set together"
        return
    fi
    
    # Check if the VPN_TYPE is supported
    VPN_TYPE=$(echo $VPN_TYPE | tr '[:upper:]' '[:lower:]')
    if [ "$VPN_TYPE" != "openvpn" ] && [ "$VPN_TYPE" != "wireguard" ]; then
        __send_log "ERROR" "VPN_TYPE not supported"
        return
    fi

    # Start the VPN connection
    __send_log "INFO" "Attempting $VPN_TYPE connection"
    if [ "$VPN_TYPE" == "openvpn" ]; then
        __func_wrapper __start_openvpn
    elif [ "$VPN_TYPE" == "wireguard" ]; then
        __func_wrapper __start_wireguard
    fi
}

__send_log "INFO" "Running $0"

__func_wrapper __enable_ip_forward
__func_wrapper __run_script "fwrules.sh"
__func_wrapper __start_vpn
__func_wrapper __run_script "commands.sh"

# TODO: Add a healthcheck
__send_log "INFO" "Container is ready"

exec /bin/sh
