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

# Load env vars
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

# run fixuid
eval "$(fixuid -q)"

# Check if app-config is present
if [ -f /app-config ]; then
    # We expect that app-config handles the launch of app command
    echo "| ENTRYPOINT: Executing app-config..."
    # shellcheck source=/dev/null
    source /app-config "$@"
else
    # Let default CMD run if app-config is not mounted
    echo "| ENTRYPOINT: app-config was not mounted, running container with given command or default command"
    exec "$@"
fi
