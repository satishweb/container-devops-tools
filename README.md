# DevOps Tools Container Image with useful cli tools - Works on amd64 and arm64

## Setup

### Setup: Mac M1/x86
- `brew install colima`
- `colima start --cpu 8 --memory 16 --disk 150`
- `sudo rm /var/run/docker.sock`
- `sudo ln -s ${HOME}/.colima/default/docker.sock /var/run/docker.sock`

### Setup: Mac M1 (buildx)
- `brew install colima`
- `colima start --arch x86_64 --layer=true --cpu 8 --memory 16 --disk 150 -p buildx`
- `docker context use colima-buildx`
- `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`

### Setup: Linux
- Install Docker cli + Containerd
- Install docker-compose
- For buildx: `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`

## How to run the DevOps Tools container:
- Edit docker-compose-template.yaml and update volume paths as required
- Fix OMZ slowness issue caused by large git repositories `git config --global oh-my-zsh.hide-dirty 1`
- `make launch`
- `make enter`

## Troubleshooting
Error: `saml2aws complains about .saml2aws being a directory`

Fix:
- `docker-compose down`
- `rm -rf ~/.saml2aws`
- `touch ~/.saml2aws`
- `FIXUID=$(id -u) FIXGID=$(id -g) docker compose up -d`
