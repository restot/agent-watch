FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        jq \
        shellcheck \
        git \
        bc \
        make \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install bats-core from source for latest version
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats \
    && /tmp/bats/install.sh /usr/local \
    && rm -rf /tmp/bats

WORKDIR /app
COPY . .

# Default: run all tests
CMD ["make", "test"]
