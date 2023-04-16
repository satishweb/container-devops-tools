IMAGE=satishweb/devops-tools
PLATFORMS=linux/amd64,linux/arm64
# PLATFORMS=linux/amd64
WORKDIR=$(shell pwd)
KUBECTL_VERSION?=$(shell curl -L -s https://api.github.com/repos/kubernetes/kubernetes/tags \
						| jq -r '.[]|select(.name|test("^v[0-9].[0-9][0-9].[0-9]$$"))|.name' \
						| sort -r \
						| head -1 \
	)

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

test-env:
	echo "test-env: printing env values:"
	echo "Kubectl Version: ${KUBECTL_VERSION}"
	exit 1

all: build

build:
	./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${KUBECTL_VERSION}" \
	  --extra-args "--build-arg KUBECTL_VERSION=${KUBECTL_VERSION}" \
	${EXTRA_BUILD_PARAMS}

test:
	docker build --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} -t ${IMAGE}:${KUBECTL_VERSION} .

launch:
	FIXUID=$$(id -u) FIXGID=$$(id -g) docker-compose up -d

start:
	docker-compose start

pause:
	docker-compose pause

remove:
	docker-compose down

enter:
	docker exec -it devops-tools zsh
