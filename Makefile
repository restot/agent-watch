.PHONY: test test-unit test-integration test-e2e test-lint check

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
