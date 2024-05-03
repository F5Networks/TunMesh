# Sets common scripts and the REGISTRY
include ../cicd/Makefile.component_base

# Override: Using common ci/cd scripts but this repo, being a POC/Sandbox repo changes the pattern slightly
COMPONENT := tun_mesh

deploy: container lint test push-registry

container:
	docker build \
		--build-arg "build_repo_sha=$(GIT_SHA)" \
	        --build-arg "build_version=$(shell cicd/manage_version.sh -s)" \
		--label "com.f5.tun_mesh.version=$(shell cicd/manage_version.sh -s)" \
		--label "com.f5.tun_mesh.repo_clean=$(shell cicd/manage_version.sh -c)" \
		-t $(INTERNAL_IMAGE) .

# NOTE: There is no explicit container dependency for CI/CD where we do not want the test and deploy targets rebulding the image
# When running local the container target will need to be manually built
lint:
	$(CONTAINER_RUN) bundle exec rubocop

test:
	$(CONTAINER_RUN) bundle exec rspec -fd

push-registry:
	./cicd/tag_and_push_image.sh $(INTERNAL_IMAGE) $(REGISTRY)
