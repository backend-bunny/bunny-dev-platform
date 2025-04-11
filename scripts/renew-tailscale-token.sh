#!/usr/bin/env bash
set -e

# Function to log error
error() {
    echo -e >&2 "\033[1;31mERROR:\033[0m ${1}"
}

# Function to log info
info() {
    echo -e >&2 "\033[1;34mINFO:\033[0m ${1}"
}

# Function to log warning
warning() {
    echo -e >&2 "\033[1;33mWARNING:\033[0m ${1}"
}

# Function to print usage
usage() {
    echo "
Usage: $(basename "${0}") OPTIONS

Options:
  Required:
    -t,--sops-tailscale-file   <path>    Path to sops secrets file containg tailscale secrets
    -m,--sops-machine-file     <path>    Path to sops file to write generated machine keys
    -n,--node-name             <string>  Name of machine used for key when storing secret

  Optional:
    -v,--version                         Print program version" 1>&2
    exit "${1:-0}"
}

if [ -z "$1" ]
  then
    usage
fi

while [ -n "$1" ]; do
    case $1 in
        -s|--sops-tailscale-file)
            SOPS_TAILSCALE_FILE_PATH="$2"
            shift 2
            ;;
        -m|--sops-machine-file)
            SOPS_MACHINE_FILE_PATH="$2"
            shift 2
            ;;
        -n|--node-name)
            NODE_NAME="$2"
            shift 2
            ;;
        -h|--help)
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

# Sanity check for required parameters
if [ -z "$SOPS_TAILSCALE_FILE_PATH" ]; then
    error "Missing required option: -s|--sops-tailscale-file"
    usage 1
fi

if [ -z "$SOPS_MACHINE_FILE_PATH" ]; then
    error "Missing required option: -m|--sops-machine-file"
    usage 1
fi

if [ -z "$NODE_NAME" ]; then
    error "Missing required option: -n|--node-name"
    usage 1
fi


# Function to get secrets from sops
get_secrets() {
    local sops_tailscale_file_path="$1"

    sops --decrypt --extract '["tailscale"]' --output-type json "$sops_tailscale_file_path"
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
        error "getting API token: $(echo "$response" | jq -r '.message // "Unknown error"')" >&2
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
                "tags": ["tag:bunny-dev-platform"]
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
        error "creating ephemeral key: $(echo "$response" | jq -r '.message // "Unknown error"')" >&2
        exit 1
    fi

    echo "$response" | jq -r '.key'
}

# Function to update sops secret
update_sops_secret() {
    local sops_machine_file_path="$1"
    local node_name="$2"
    local tailscale_token="$3"

    sops --set "[\"tailscale\"][\"$node_name\"] \"$tailscale_token\"" "$sops_machine_file_path"
}

# Main execution flow
info "Retrieving secrets from sops file..."
secrets=$(get_secrets "$SOPS_TAILSCALE_FILE_PATH")

# Extract client ID and secret
tailscale_client_id=$(echo "$secrets" | jq -r '.clientID')
tailscale_client_secret=$(echo "$secrets" | jq -r '.clientSecret')

info "Authenticating with Tailscale..."
access_token=$(get_tailscale_api_token "$tailscale_client_id" "$tailscale_client_secret")

info "Creating new Tailscale ephemeral key..."
ephemeral_key=$(create_tailscale_ephemeral_key "$access_token")

info "Updating TAILSCALE_TOKEN in sops..."
update_sops_secret "$SOPS_MACHINE_FILE_PATH" "$NODE_NAME" "$ephemeral_key" > /dev/null

info "Updated TAILSCALE_TOKEN secret in sops with new ephemeral key"
