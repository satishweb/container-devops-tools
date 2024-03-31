IMAGE=satishweb/devops-tools
PLATFORMS=linux/amd64,linux/arm64
# PLATFORMS=linux/amd64
WORKDIR=$(shell pwd)
REPO_ROOT?=$(shell git rev-parse --show-toplevel)

DOCKER_COMPOSE_COMMAND := $(shell command -v docker-compose 2> /dev/null || echo docker compose)
DOCKER_COMPOSE_TEMP_FILE = .docker-compose.yaml

ifeq ($(strip $(PARALLEL_LEVEL)),)
	PARALLEL_LEVEL := $(shell nproc --all)
	MAKEFLAGS += -j${PARALLEL_LEVEL}
endif

# Set L to + for debug
export L=@

# Default bash flags
ifeq ($(L),+)
	export BASH_FLAGS=-x
endif
export SHELL := /bin/bash $(BASH_FLAGS)

# Handle sed flags issue for macos
export OSV=$(shell uname|awk '{ print $$1 }')

ifeq ($(strip $(OSV)),Darwin)
	export SED_I_FLAG=-i ''
else
	export SED_I_FLAG=-i
endif

# Disable bad '-' value for L
# We dont want to ignore errors for all commands in targets
# To ignore errors, modify the Makefiles
ifeq ($(L),-)
	export L=+
endif

ifdef PUSH
	EXTRA_BUILD_PARAMS += --push-images --push-git-tags
endif

ifdef LATEST
	EXTRA_BUILD_PARAMS += --mark-latest
endif

ifdef NO-CACHE
	EXTRA_BUILD_PARAMS += --no-cache
endif

ifdef LOAD
	EXTRA_BUILD_PARAMS += --load
endif

.DEFAULT_GOAL := default

.PHONY: default
default:
	$(L)echo "ERR: Make target name is expected as argument"
	$(L)echo "------"
	$(L)echo "Targets:"
	$(L)grep '^[^#[:space:]].*:' ${REPO_ROOT}/Makefile ${REPO_ROOT}/*.mk 2>/dev/null \
		| grep -v -e "\.PHONY\|\.DEFAULT_GOAL\|export .*=.*\|default:" \
		| sed 's/\(.*\):\(.*\):\(.*\)/  \2/g'
	$(L)echo "------"

.PHONY: build-all
build-all:
	$(L)echo "Building all versions..."
	$(L)versions=$$(make -s kubectl-versions); \
	echo "Versions to build:"; \
	echo "$$versions"| sed 's/^/  - /'; \
	first_version=$$(echo "$$versions" | head -n 1); \
	make build KUBECTL_VERSION=$$first_version LATEST=yes PUSH=yes L=$(L); \
	# echo "$$versions" | tail -n +2 | xargs -I {} -P $$(nproc) make build KUBECTL_VERSION={} PUSH=yes ;\
	for version in $$(echo $$versions|echo "$$versions" | tail -n +2); do \
		make build KUBECTL_VERSION=$$version PUSH=yes L=$(L); \
	done

.PHONY: kubectl-version
kubectl-version:
	$(L)curl -L -s https://api.github.com/repos/kubernetes/kubernetes/tags \
		| jq -r '.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$$")) | .name' \
		| sort -r \
		| head -n 1

.PHONY: kubectl-versions
kubectl-versions:
	$(L)tags_url="https://api.github.com/repos/kubernetes/kubernetes/tags?per_page=100"; \
	response=$$(curl -s "$$tags_url"); \
	filtered_tags=$$(echo "$$response" | jq -r '.[].name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$$"))'); \
	echo "$$filtered_tags" | sort -rV | uniq -w 5 | head -n 4

.PHONY: build
build:
	$(L)./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${KUBECTL_VERSION}" \
	  --extra-args "--build-arg KUBECTL_VERSION=${KUBECTL_VERSION}" \
	  ${EXTRA_BUILD_PARAMS}

.PHONY: test
test:
	$(L)version=$$(make -s kubectl-version); \
		docker build --build-arg KUBECTL_VERSION=$$version -t ${IMAGE}:$$version .

.PHONY: launch
launch:
	$(L)[ -f ${DOCKER_COMPOSE_TEMP_FILE} ] && rm -f ${DOCKER_COMPOSE_TEMP_FILE} || true
	$(L)cp docker-compose-template.yaml ${DOCKER_COMPOSE_TEMP_FILE}
	$(L)mkdir -p \
		${HOME}/.kube \
		${HOME}/.docker \
		${HOME}/.aws \
		${HOME}/.ssh \
		${HOME}/.gnupg \
		${HOME}/.vim \
		${HOME}/Documents
	$(L)touch \
		${HOME}/.saml2aws \
		${HOME}/.gitconfig \
		${HOME}/.git-credentials \
		${HOME}/.zsh_history
	$(L)FIXUID=$$(id -u) FIXGID=$$(id -g) ${DOCKER_COMPOSE_COMMAND} -f ${DOCKER_COMPOSE_TEMP_FILE} up -d

.PHONY: start
start:
	$(L)${DOCKER_COMPOSE_COMMAND} -f ${DOCKER_COMPOSE_TEMP_FILE} start

.PHONY: pause
pause:
	$(L)${DOCKER_COMPOSE_COMMAND} -f ${DOCKER_COMPOSE_TEMP_FILE} pause

.PHONY: remove
remove:
	$(L)${DOCKER_COMPOSE_COMMAND} -f ${DOCKER_COMPOSE_TEMP_FILE} down

.PHONY: enter
enter:
	$(L)docker exec -it devops-tools zsh || true
