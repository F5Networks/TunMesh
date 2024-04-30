# Sets common scripts and the REGISTRY
include ../cicd/Makefile.component_base

# Override: Using common ci/cd scripts but this repo, being a POC/Sandbox repo changes the pattern slightly
COMPONENT := tun_mesh

deploy: container lint test push-registry

# NOTE: There is no explicit container dependency for CI/CD where we do not want the test and deploy targets rebulding the image
# When running local the container target will need to be manually built
lint:
	$(CONTAINER_RUN) bundle exec rubocop

test:
	$(CONTAINER_RUN) bundle exec rspec -fd

push-registry:
	./cicd/tag_and_push_image.sh $(INTERNAL_IMAGE) $(REGISTRY)
