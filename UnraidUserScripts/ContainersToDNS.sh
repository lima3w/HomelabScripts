#!/bin/bash

# USE THIS SCRIPT TO TAKE THE NAMES OF ALL DOCKER CONTAINERS, APPEND THE DOMAIN TO THE END OF THE CONTAINER NAME TO CREATE THE FQDN, THEN ENSURE ALL DNS ENTRIES ARE CORRECT TO POINT TO YOUR LOAD BALANCER
# I use Technitium DNS and NGINX Proxy Manager for this.
# Add this to your unraid user scripts on a schedule to make sure you always have updated dns records

ADD_API_URL="http://technitium:5380/api/zones/records/add"  # API URL for adding DNS records
UPDATE_API_URL="http://technitium:5380/api/zones/records/update"  # API URL for updating DNS records
API_KEY="api_key_here"  # Replace with your actual API key
DOMAIN="domain" # This will be appended to your container names 
target_cname="loadbalancer.tld" # This is the load balancer, such as NGINX Proxy Manager, that will handle all of the traffic

update_dns_record() {
    local container_name="$1"
    # Initialize payload with mandatory fields including the token
    local payload="token=$API_KEY&domain=$container_name&type=CNAME&value=$target_cname&ttl=3600"

    # Make the API call to update the DNS record
    response=$(curl -s -X POST "$UPDATE_API_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data "$payload")
    if [[ "$response" == *"\"status\":\"ok\""* ]]; then
        echo "Successfully updated DNS record for $container_name."
    else
        echo "Failed to update DNS record for $container_name. Response: $response"
    fi
}

add_dns_record() {
    local container_name="$1"
    # Initialize payload with mandatory fields including the token
    local payload="token=$API_KEY&domain=$container_name&type=CNAME&value=$target_cname&ttl=3600"
    # Make the API call to add the DNS record
    response=$(curl -s -X POST "$ADD_API_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data "$payload")
    if [[ "$response" == *"\"status\":\"ok\""* ]]; then
        echo "Successfully added DNS record for $container_name."
    else
        echo "Failed to add DNS record for $container_name. Response: $response"
    fi
}

check_dns_cname() {
    local container_name="$1"

    # Check DNS entry
    cname_target=$(dig +short CNAME "$container_name")

	if [[ -z "$cname_target" ]]; then
		echo "$container_name does not exist. Adding... "
		add_dns_record "$container_name"
  elif [[ "$cname_target" == "$target_cname." ]]; then
        echo "$container_name is correctly pointing to $target_cname."
  else
        echo "$container_name does NOT point to $target_cname. Updating DNS..."
        update_dns_record "$container_name"
  fi
}

process_containers() {
    # Get list of running container names
    docker ps --format "{{.Names}}" | while read -r container_name; do
        # Convert container name to lowercase
        container_name=$(echo "$container_name" | tr '[:upper:]' '[:lower:]')

        # Append domain if not already appended
        if [[ ! "$container_name" == *."$DOMAIN" ]]; then
            container_name+=".$DOMAIN"
        fi

        # Check DNS entry
        check_dns_cname "$container_name"
    done
}

# Main script execution
if [[ "$BASH_SOURCE" == "$0" ]]; then
    echo "Checking DNS entries for Docker containers..."
    process_containers
fi
