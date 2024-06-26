# syntax=docker/dockerfile:1

ARG BASE=public.ecr.aws/ubuntu/ubuntu:24.04

###

FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/rust:1.77-slim-bullseye as build-healthz
RUN rustup target add aarch64-unknown-linux-gnu
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      gcc-aarch64-linux-gnu

WORKDIR /build/healthz
COPY healthz/ ./

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/build/healthz/target \
    CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
    cargo install --path . --root /app --locked --target=aarch64-unknown-linux-gnu

###

FROM --platform=$BUILDPLATFORM $BASE as build-stork

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git rake build-essential wget unzip python3

WORKDIR /build
RUN git clone --depth=1 https://gitlab.isc.org/isc-projects/stork -b v1.15.0

WORKDIR /build/stork/backend
ENV GOPATH=/build/go

RUN --mount=type=cache,dst=/build/stork/tools \
    rake build:agent

ENV GOOS=linux
ENV GOARCH=arm64
ENV CGO_ENABLED=0

RUN --mount=type=cache,dst=/build/stork/tools \
    ../tools/golang/go/bin/go install ./cmd/stork-agent

###

FROM --platform=$BUILDPLATFORM $BASE as config
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y jsonnet
WORKDIR /app
COPY kea-ctrl-agent.jsonnet /tmp/
RUN jsonnet /tmp/kea-ctrl-agent.jsonnet > /app/kea-ctrl-agent.json

###

FROM $BASE

RUN mkdir -p /run/kea /app
VOLUME /run/kea

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates \
      dumb-init \
      ruby \
      iproute2 \
      kea \
      mysql-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=build-healthz /app/bin/healthz /app/healthzd
COPY --from=build-stork /build/go/bin/linux_arm64/stork-agent /app/stork-agent
COPY run.sh /app/run.sh
COPY choose_dhcp_server_id.rb /app/choose_dhcp_server_id.rb
COPY --from=config /app/kea-ctrl-agent.json /app/kea-ctrl-agent.json

RUN kea-ctrl-agent -t /app/kea-ctrl-agent.json

CMD /app/run.sh
