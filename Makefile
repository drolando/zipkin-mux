DOCKER_TAG ?= zipkin-mux-$(USER)
DOCKER_COMPOSE_VERSION := 1.21.2
DOCKER_COMPOSE := bin/docker-compose-$(DOCKER_COMPOSE_VERSION)

.PHONY: cook-image
cook-image:
	docker build -t $(DOCKER_TAG) .

$(DOCKER_COMPOSE):
	mkdir -p bin/
	# From https://docs.docker.com/compose/install/#prerequisites
	# docker-compose is a statically linked go binary, so we can simply download the binary and use it
	curl -L https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-`uname \
		-s`-`uname -m` -o $(DOCKER_COMPOSE)
	chmod +x $(DOCKER_COMPOSE)

run: cook-image $(DOCKER_COMPOSE)
	$(DOCKER_COMPOSE) run --service-ports zipkin-mux

clean:
	$(DOCKER_COMPOSE) kill
	$(DOCKER_COMPOSE) rm -fs
