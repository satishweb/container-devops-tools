IMAGE=satishweb/devops-tools
PLATFORMS=linux/amd64,linux/arm64
# PLATFORMS=linux/amd64
WORKDIR=$(shell pwd)
REPO_ROOT?=$(shell git rev-parse --show-toplevel)

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
	@echo "ERR: Make target name is expected as argument"
	@echo "------"
	@echo "Targets:"
	@grep '^[^#[:space:]].*:' ${REPO_ROOT}/Makefile ${REPO_ROOT}/*.mk 2>/dev/null \
		| grep -v -e "\.PHONY\|\.DEFAULT_GOAL\|export .*=.*\|default:" \
		| sed 's/\(.*\):\(.*\):\(.*\)/  \2/g'
	@echo "------"

.PHONY: build-all
build-all:
	@echo "Building all versions..."
	@versions=$$(make -s kubectl-versions); \
	version_count=$$(echo "$$versions" | wc -l); \
	echo "Number of versions to build: $$version_count"; \
	echo "Versions to build:"; \
	echo "$$versions"| sed 's/^/  - /'; \
	echo "$$versions" | xargs -I {} -P $$(nproc) make build KUBECTL_VERSION={}

.PHONY: kubectl-version
kubectl-version:
	@curl -L -s https://api.github.com/repos/kubernetes/kubernetes/tags \
		| jq -r '.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$$")) | .name' \
		| sort -r \
		| head -n 1

.PHONY: kubectl-versions
kubectl-versions:
	@tags_url="https://api.github.com/repos/kubernetes/kubernetes/tags?per_page=100"; \
	response=$$(curl -s "$$tags_url"); \
	filtered_tags=$$(echo "$$response" | jq -r '.[].name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$$"))'); \
	echo "$$filtered_tags" | sort -rV | uniq -w 5 | head -n 4

.PHONY: build
build:
	./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${KUBECTL_VERSION}" \
	  --extra-args "--build-arg KUBECTL_VERSION=${KUBECTL_VERSION}" \
	${EXTRA_BUILD_PARAMS}

.PHONY: test
test:
	@version=$$(make -s kubectl-version); \
		docker build --build-arg KUBECTL_VERSION=$$version -t ${IMAGE}:$$version .

.PHONY: launch
launch:
	[[ ! -f docker-compose.yaml ]] && cp docker-compose-template.yaml docker-compose.yaml
	@mkdir -p \
		${HOME}/.devops-tools-home \
		${HOME}/.kube \
		${HOME}/.docker \
		${HOME}/.aws \
		${HOME}/.ssh \
		${HOME}/.gnupg \
		${HOME}/.vim \
		${HOME}/Documents
	@touch \
		${HOME}/.saml2aws \
		${HOME}/.gitconfig \
		${HOME}/.zsh_history
	FIXUID=$$(id -u) FIXGID=$$(id -g) docker-compose up -d

.PHONY: start
start:
	docker-compose start

.PHONY: pause
pause:
	docker-compose pause

.PHONY: remove
remove:
	docker-compose down

.PHONY: enter
enter:
	docker exec -it devops-tools zsh
