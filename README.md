# DevOps Tools Container Image

## Overview
This Docker container image provides a curated set of command-line tools essential for developers, SREs, and DevOps engineers. It aims to streamline development workflows, simplify infrastructure management, and facilitate troubleshooting tasks.

## Features
- Pre-installed with a comprehensive suite of CLI tools
- Optimized for both Mac M1/x86 and Linux platforms
- Easy setup and configuration using Docker Compose
- Includes troubleshooting tips and solutions for common issues

## Container Environment Installation
1. **Mac M1/x86 Setup:**
    - Install [Colima](https://colima.sh/)
    - Start Colima with appropriate resources: `colima start --cpu 8 --memory 16 --disk 150`
    - Symlink Docker socket: `sudo ln -s ${HOME}/.colima/default/docker.sock /var/run/docker.sock`

2. **Mac M1 (Buildx) Setup (optional):**
    - Install Colima: `brew install colima`
    - Start Colima with buildx: `colima start --arch x86_64 --cpu 8 --memory 16 --disk 150 -p buildx`
    - Use Colima buildx context: `docker context use colima-buildx`
    - Enable qemu-user-static: `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`

3. **Linux Setup:**
    - Install Docker CLI and Containerd
    - Install Docker Compose
    - For Buildx support, enable qemu-user-static

## Usage
1. Edit `docker-compose-template.yaml` for volume paths customization
2. Fix Oh My ZSH slowness: `git config --global oh-my-zsh.hide-dirty 1`
3. Launch the container: `make launch`
4. Enter the container: `make enter`

## Troubleshooting
**Issue:** saml2aws complains about `.saml2aws` being a directory

**Solution:**
1. Stop Docker Compose: `docker-compose down`
2. Remove existing `.saml2aws`: `rm -rf ~/.saml2aws`
3. Recreate `.saml2aws`: `touch ~/.saml2aws`
4. Start Docker Compose with fixuid: `FIXUID=$(id -u) FIXGID=$(id -g) docker compose up -d`

## Contributions
Contributions to enhance and expand the toolset or improve the Dockerfile are welcome. Please fork this repository, make your changes, and submit a pull request. Make sure to follow the project's guidelines and conventions.

## License
This project is licensed under the [Apache License](LICENSE).
