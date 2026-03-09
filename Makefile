.PHONY: test test-unit test-integration test-e2e test-lint check \
       docker-build docker-test docker-coverage

BATS := bats

test-lint:
	$(BATS) test/lint/

test-unit:
	$(BATS) test/unit/

test-integration:
	$(BATS) test/integration/

test-e2e:
	$(BATS) test/e2e/

test: test-lint test-unit test-integration test-e2e

check:
	bash -n agent-watch
	$(BATS) test/unit/

DOCKER_IMAGE := agent-watch-test

docker-build:
	docker build -t $(DOCKER_IMAGE) .

docker-test: docker-build
	docker run --rm $(DOCKER_IMAGE)

docker-coverage: docker-build
	docker run --rm -v "$(CURDIR)":/out $(DOCKER_IMAGE) \
		sh -c 'bash coverage.sh --html && cp coverage-badge.svg /out/ && cp -r coverage /out/ 2>/dev/null || true'
