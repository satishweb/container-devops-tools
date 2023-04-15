# DevOps Tools Container Image with useful cli tools - Works on amd64 and arm64

## Setup

### Setup: Mac
- `brew install colima`
- `colima start --cpu 8 --memory 8 --disk 150`
- `sudo rm /var/run/docker.sock`
- `sudo ln -s ${HOME}/.colima/default/docker.sock /var/run/docker.sock`

### Setup: Linux
- Install Docker cli + Containerd
- Install docker-compose

## How to run the DevOps Tools container:
`FIXUID=$(id -u) FIXGID=$(id -g) docker compose up -d`
`docker exec -it devops-tools zsh`

## Troubleshooting
Error: `saml2aws complains about .saml2aws being a directory`

Fix:
- `docker-compose down`
- `rm -rf ~/.saml2aws`
- `touch ~/.saml2aws`
- `FIXUID=$(id -u) FIXGID=$(id -g) docker compose up -d`

