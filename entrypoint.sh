#!/bin/zsh
# Author: Satish Gaikwad <satish@satishweb.com>
set -e

if [ -f /run/secrets/DEBUG ]; then
    DEBUG=$(cat "$i")
    export DEBUG
fi

if [ "$DEBUG" = "1" ]; then
    set -x
fi

printf "|---------------------------------------------------------------------------------------------\n";
printf "| Starting DevOps Tools Container \n"

## Load env vars [ k8s compatibility ]
printf "| ENTRYPOINT: \033[0;31mDeclaring and exporting container secrets in the current shell (/run/secrets/*)...\033[0m\n"
for i in $(env|grep '/run/secrets')
do
    varName=$(awk -F '[=]' '{print $1}' <<< "$i" | sed 's/_FILE//')
    varFile=$(awk -F '[=]' '{print $2}' <<< "$i")
    exportCmd="export $varName=$(cat "$varFile")"
    echo "${exportCmd}" >> /etc/profile
    eval "${exportCmd}"
    printf "| ENTRYPOINT: Exporting var: %s\n" "$varName"
done

## Run fixuid to update home dir contents ownership to given uid and gid

eval "$(fixuid -q)"

## Setup home dir

# Update home dir path for devops user
sudo sed -i "s/\/home\/devops/$(echo ${HOME}|sed 's/\//\\\//g')/g" /etc/passwd

# Change home dir ownership to current uid and gid
cd "$HOME"
sudo chown $(id -u):$(id -g) ${HOME}

# Create symlinks to the important directories and files from devops's original home dir
HOME_FILES="$(ls -a /home/devops/)"
echo "$HOME_FILES" | while IFS= read -r f
do
    if [ ! -e $f ]; then
        ln -s /home/devops/$f ./
    fi
done

## GPG and pass manager setup

# Generate default gpg key without the password
if [ ! -f ${HOME}/.gnupg/pubring.kbx ]; then
    gpg --batch --passphrase '' --quick-gen-key devops default default
fi

# Run gpg command to make sure gpg agent starts in a daemon mode.
gpg --list-secret-keys >/dev/null 2>&1

# Initialize pass manager with default gpg id
if [ ! -f ${HOME}/.password-store/.gpg-id ]; then
    pass init $(gpg --list-keys devops|awk 'NR==2{print $1;exit}')
fi

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
