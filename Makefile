SHELL := /bin/sh
REPO_CICD_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
GIT_SHA := $(shell git rev-parse HEAD)
TIMESTAMP := $(shell date -u '+%s')

INTERNAL_IMAGE="tun_mesh:current-build"
REGISTRY="tun_mesh" # TODO: Final repo

CONTAINER_RUN = docker run --rm --entrypoint="" $(INTERNAL_IMAGE)

# The default target is the first command
default: all

# https://stackoverflow.com/questions/44492805/declare-all-targets-phony
.PHONY: *

all: container test lint

clean:
	docker rmi $(INTERNAL_IMAGE) || /bin/true

deploy: container lint test push-registry

container:
	docker build \
		--build-arg "build_repo_sha=$(GIT_SHA)" \
	        --build-arg "build_version=$(shell cicd/manage_version.sh -s)" \
		--label "com.f5.tun_mesh.version=$(shell cicd/manage_version.sh -s)" \
		--label "com.f5.tun_mesh.repo_clean=$(shell cicd/manage_version.sh -c)" \
		-t $(INTERNAL_IMAGE) .

lint: container
	$(CONTAINER_RUN) bundle exec rubocop

test: container
	$(CONTAINER_RUN) bundle exec rspec -fd

push-registry:
	./cicd/tag_and_push_image.sh $(INTERNAL_IMAGE) $(REGISTRY)
