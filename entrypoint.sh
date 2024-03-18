#!/bin/bash
# Author: Satish Gaikwad <satish@satishweb.com>
# Note: Privilege escalation is required to change ownership of the HOME dir
set -euo pipefail

: "${DEBUG:=0}"

if [ -f /run/secrets/DEBUG ]; then
    DEBUG=$(< "/run/secrets/DEBUG")
    export DEBUG
fi

if [ "$DEBUG" = "1" ]; then
    set -x
fi

# Check if HOME variable is defined, if not, set default value
if [ -z "${HOME}" ]; then
    export HOME="/home/ubuntu"
fi

# Check if USER variable is defined, if not, set default value
if [ -z "${USER}" ]; then
    export USER="ubuntu"
fi

print_divider() {
    printf "|---------------------------------------------------------------------------------------------\n"
}

print_divider
printf "| Starting Tools Container \n"

## Load env vars [ docker-compose compatibility ]
if ! curl --output /dev/null --silent --head --fail http://kubernetes.default.svc.cluster.local; then
    if [ -d "/run/secrets/" ]; then
        printf "| ENTRYPOINT: \033[0;31mDeclaring and exporting container secrets in the current shell (/run/secrets/*)...\033[0m\n"
        while IFS= read -r -d '' i; do
            varName=$(basename "$i" | sed 's/_FILE//')
            exportCmd="export $varName=$(< "$i")"
            echo "${exportCmd}" >> /etc/profile
            eval "${exportCmd}"
            printf "| ENTRYPOINT: Exporting var: %s\n" "$varName"
        done < <(find /run/secrets/ -type f -print0 | grep -z '.')
    fi
fi

## Run fixuid to update home dir contents ownership to given uid and gid
(printf "user: %s\ngroup: %s\npaths:\n  - %s\n" "${USER}" "${USER}" "${HOME}" | sudo tee /etc/fixuid/config.yml > /dev/null) || true

eval "$(fixuid -q)"

## Setup home dir
HOME_TEMPLATE=/home/ubuntu

if [[ "$HOME" != "$HOME_TEMPLATE" && $HOME ]]; then
    # If the HOME dir is not the default one, change ownership of the new HOME dir to the current user
    if [ ! -f "${HOME}/.keep" ]; then
        # Note: If HOME dir data is persisted and USER ID or GROUP ID is changed
        # then ownership of the HOME dir needs to be changed to the new USER ID and GROUP ID manually
        sudo chown -Rf "$(id -u)":"$(id -g)" "${HOME}"
        touch "${HOME}/.keep"
    fi
    items_to_copy=(
        "${HOME_TEMPLATE}/.oh-my-zsh"
        "${HOME_TEMPLATE}/.cache"
        "${HOME_TEMPLATE}/.local"
        "${HOME_TEMPLATE}/.config"
        "${HOME_TEMPLATE}/.krew"
        "${HOME_TEMPLATE}/.aws_cli_functions"
        "${HOME_TEMPLATE}/.kubectl_aliases"
        "${HOME_TEMPLATE}/.tmux.conf"
        "${HOME_TEMPLATE}/.vimrc"
        "${HOME_TEMPLATE}/.wget-hsts"
        "${HOME_TEMPLATE}/.zshrc"
    )
    for item in "${items_to_copy[@]}"; do
        if [ ! -e "${HOME}/$(basename "$item")" ]; then
            # We do copying over linking to allow persistence of the HOME dir data
            # when home dir is mounted as a volume
            cp -rf "$item" "${HOME}" || true
        fi
    done
fi

## GPG and pass manager setup [ For CLI OIDC authenticators such as saml2aws via Okta ]

# Generate default gpg key without the password
if [ ! -f "${HOME}/.gnupg/pubring.kbx" ]; then
    gpg --batch --passphrase '' --quick-gen-key user default default
fi

# Run gpg command to make sure gpg agent starts in a daemon mode.
gpg --list-secret-keys >/dev/null 2>&1

# Initialize pass manager with default gpg id
if [ ! -f "${HOME}/.password-store/.gpg-id" ]; then
    pass init "$(gpg --list-keys user|awk 'NR==2{print $1;exit}')"
fi

# Function to update a key in the JSON file for YAI CLI AI tool
update_key() {
    local key="$1"
    local value="$2"
    sed -i "s/\"$key\": .*/\"$key\": \"$value\",/" "${HOME}/.config/yai.json"
}

# List of environment variables and their corresponding keys in the JSON file
env_keys=(
    "OPENAI_API_KEY=openai_key"
    "OPENAI_MAX_TOKENS=openai_max_tokens"
    "OPENAI_MODEL=openai_model"
    "OPENAI_PROXY=openai_proxy"
    "OPENAI_TEMPERATURE=openai_temperature"
    "USER_DEFAULT_PROMPT_MODE=user_default_prompt_mode"
    "USER_PREFERENCES=user_preferences"
)

# Iterate over the environment variables and update the JSON file
for env_key in "${env_keys[@]}"; do
    env_var="${env_key%%=*}"
     if declare -p "$env_var" &>/dev/null && [ -n "${!env_var}" ]; then
        update_key "${env_key#*=}" "${!env_var}"
    fi
done

printf "| Initialization complete! Container ready for use \n"
print_divider

# Check if app-config is present
if [ -f /app-config ]; then
    # We expect that app-config handles the launch of container default command
    echo "| ENTRYPOINT: Executing app-config..."
    # shellcheck source=/dev/null
    source /app-config "$@"
else
    # Lets run the default CMD if app-config is not mounted
    echo "| ENTRYPOINT: app-config was not mounted, running container with given command or default command"
    echo "|             Container is ready to use"
    exec "$@"
fi
