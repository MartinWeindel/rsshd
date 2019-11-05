
IMAGE_REPOSITORY   := docker.io/mweindel/rsshd
IMAGE_TAG          := latest


.PHONY: docker-image
docker-image:
	@docker build -t $(IMAGE_REPOSITORY):$(IMAGE_TAG) --rm .

.PHONY: docker-push
docker-push:
	@docker push $(IMAGE_REPOSITORY):$(IMAGE_TAG)
