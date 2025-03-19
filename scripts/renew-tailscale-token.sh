#!/bin/bash
set -e

error() {
    echo -e >&2 "\033[1;31mERROR:\033[0m ${1}"
}

info() {
    echo -e >&2 "\033[1;34mINFO:\033[0m ${1}"
}

warning() {
    echo -e >&2 "\033[1;33mWARNING:\033[0m ${1}"
}

usage() {
    echo "
Usage: $(basename "${0}") OPTIONS

Options:
  Required:
    -s,--sops-file   <path>    Path to sops secrets file

  Optional:
    -v,--version                               Print program version" 1>&2
    exit "${1:-0}"
}

while [ -n "$1" ]; do
    case $1 in
        -s|--sops-file)
            SOPS_FILE_PATH="$1"
            shift 2
            ;;
        --help)
            usage 0
            ;;
        -v|--version)
            echo "renew-tailscale-token version $VERSION"
            exit 0
            ;;
        -*)
            error "Unknown option: '$1'"
            usage 1
            ;;
        *)
            error "Unknown option: '$1'"
            usage 1
            ;;
    esac
    # shellcheck disable=SC2181
    [ $? -ne 0 ] && echo "Broke when parsing options: '$1'" && usage 1
done




# Configuration variables
# These should be set as environment variables or passed as arguments
DOPPLER_TOKEN=${DOPPLER_TOKEN:-"your_doppler_token"}
PROJECT=${PROJECT:-"your_project"}
CONFIG=${CONFIG:-"your_config"}

# Function to get secrets from Doppler
get_secrets() {
    local token="$1"

    response=$(curl -s -X GET "https://api.doppler.com/v3/configs/config/secrets" \
        -H "Authorization: Bearer $token")

    # Check if the request was successful
    if [[ $(echo "$response" | jq -r 'has("secrets")') != "true" ]]; then
        echo "Error retrieving secrets: $(echo "$response" | jq -r '.message // "Unknown error"')" >&2
        exit 1
    fi

    echo "$response"
}

# Function to get Tailscale API token
get_tailscale_api_token() {
    local client_id="$1"
    local client_secret="$2"

    response=$(curl -s -X POST "https://api.tailscale.com/api/v2/oauth/token" \
        -d "client_id=$client_id" \
        -d "client_secret=$client_secret" \
        -d "grant_type=client_credentials")

    # Check if the request was successful
    if [[ $(echo "$response" | jq -r 'has("access_token")') != "true" ]]; then
        echo "Error getting API token: $(echo "$response" | jq -r '.message // "Unknown error"')" >&2
        exit 1
    fi

    echo "$response" | jq -r '.access_token'
}

# Function to create Tailscale ephemeral key
create_tailscale_ephemeral_key() {
    local token="$1"

    # Prepare the JSON payload
    payload=$(cat <<EOF
{
    "capabilities": {
        "devices": {
            "create": {
                "reusable": true,
                "ephemeral": true,
                "preauthorized": true,
                "tags": ["tag:all"]
            }
        }
    },
    "expirySeconds": 86400,
    "description": "ephem token"
}
EOF
)

    response=$(curl -s -X POST "https://api.tailscale.com/api/v2/tailnet/-/keys" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$payload")

    # Check if the request was successful
    if [[ $(echo "$response" | jq -r 'has("key")') != "true" ]]; then
        echo "Error creating ephemeral key: $(echo "$response" | jq -r '.message // "Unknown error"')" >&2
        exit 1
    fi

    echo "$response" | jq -r '.key'
}

# Function to update Doppler secret
update_doppler_secret() {
    local token="$1"
    local project="$2"
    local config="$3"
    local tailscale_token="$4"

    # Prepare the JSON payload
    payload=$(cat <<EOF
{
    "project": "$project",
    "config": "$config",
    "change_requests": [
        {
            "name": "TAILSCALE_TOKEN",
            "originalName": "TAILSCALE_TOKEN",
            "value": "$tailscale_token"
        }
    ]
}
EOF
)

    response=$(curl -s -X POST "https://api.doppler.com/v3/configs/config/secrets" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$payload")

    # Check if the request was successful
    if [[ $(echo "$response" | jq -r 'has("secrets")') != "true" ]]; then
        echo "Error updating secret: $(echo "$response" | jq -r '.message // "Unknown error"')" >&2
        exit 1
    fi

    echo "$response"
}

# Check for required dependencies
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed."; exit 1; }

# Main execution flow
echo "Retrieving secrets from Doppler..."
secrets=$(get_secrets "$DOPPLER_TOKEN")

# Extract client ID and secret
tailscale_client_id=$(echo "$secrets" | jq -r '.secrets.OAUTH_DEVICES_CLIENT_ID.raw')
tailscale_client_secret=$(echo "$secrets" | jq -r '.secrets.OAUTH_DEVICES_CLIENT_SECRET.raw')

echo "Authenticating with Tailscale..."
access_token=$(get_tailscale_api_token "$tailscale_client_id" "$tailscale_client_secret")

echo "Creating new Tailscale ephemeral key..."
ephemeral_key=$(create_tailscale_ephemeral_key "$access_token")

echo "Updating TAILSCALE_TOKEN in Doppler..."
update_doppler_secret "$DOPPLER_TOKEN" "$PROJECT" "$CONFIG" "$ephemeral_key" > /dev/null

echo "Updated TAILSCALE_TOKEN secret in doppler with new ephemeral key"