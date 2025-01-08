#!/bin/bash

# Configuration variables
TIMEOUT=10

# ANSI colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log message to console
print_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        "ERROR")
            echo -e "${timestamp} - ${RED}${message}${NC}"
            ;;
        "SUCCESS")
            echo -e "${timestamp} - ${GREEN}${message}${NC}"
            ;;
        "WARNING")
            echo -e "${timestamp} - ${YELLOW}${message}${NC}"
            ;;
        *)
            echo -e "${timestamp} - ${message}"
            ;;
    esac
}

# Check for updates on a specific server
check_updates() {
    local server="$1"
    local updates=""
    
    print_message "INFO" "Checking updates on $server..."
    
    # Try to detect the OS and run appropriate update check command
    local os_type=$(ssh "$server" "cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d'=' -f2 | tr -d '\"'")
    
    case "$os_type" in
        "ubuntu"|"debian")
            updates=$(ssh "$server" '
                export DEBIAN_FRONTEND=noninteractive
                apt-get update >/dev/null 2>&1
                apt-get -s upgrade | grep -P "^[0-9]+ upgraded" || echo "0 upgraded"
            ')
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            updates=$(ssh "$server" '
                yum check-update --quiet | grep -v "^$" | wc -l
            ')
            ;;
        *)
            print_message "WARNING" "Unknown OS on $server. Skipping update check."
            return 1
            ;;
    esac
    
    # Parse update count and log result
    if [[ "$os_type" == "ubuntu" || "$os_type" == "debian" ]]; then
        local update_count=$(echo "$updates" | grep -oP '^[0-9]+')
        if [ "$update_count" -gt 0 ]; then
            print_message "WARNING" "$server: $updates"
        else
            print_message "SUCCESS" "$server: System is up to date"
        fi
    else
        # For RHEL-based systems, subtract 1 from count (due to header line)
        local update_count=$((updates - 1))
        if [ "$update_count" -gt 0 ]; then
            print_message "WARNING" "$server: $update_count updates available"
        else
            print_message "SUCCESS" "$server: System is up to date"
        fi
    fi
}

# Main function
main() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: $0 user@server"
        echo "Example: $0 admin@server.example.com"
        exit 1
    }

    local server="$1"
    check_updates "$server"
}

# Run main function
main "$@"
