# DevOps Tools Container Image with useful cli tools - Works on amd64 and arm64

## Setup

### Setup: Mac
- `brew install colima`
- `colima start --arch x86_64 --layer=true --cpu 8 --memory 16 --disk 150`
- `sudo rm /var/run/docker.sock`
- `sudo ln -s ${HOME}/.colima/default/docker.sock /var/run/docker.sock`
- `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`

### Setup: Linux
- Install Docker cli + Containerd
- Install docker-compose
- `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`

## How to run the DevOps Tools container:
- `cp docker-compose-template.yaml docker-compose.yaml`
- `FIXUID=$(id -u) FIXGID=$(id -g) docker compose up -d`
- `docker exec -it devops-tools zsh`

## Troubleshooting
Error: `saml2aws complains about .saml2aws being a directory`

Fix:
- `docker-compose down`
- `rm -rf ~/.saml2aws`
- `touch ~/.saml2aws`
- `FIXUID=$(id -u) FIXGID=$(id -g) docker compose up -d`
