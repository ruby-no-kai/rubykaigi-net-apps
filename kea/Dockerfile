# syntax=docker/dockerfile:1

ARG BASE=public.ecr.aws/ubuntu/ubuntu:24.04

###

FROM public.ecr.aws/docker/library/rust:1.85-slim-bookworm as build-healthz

WORKDIR /build/healthz
COPY healthz/ ./

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/build/healthz/target \
    cargo install --path . --root /app --locked

###

FROM $BASE as build-stork

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git rake build-essential wget unzip python3

WORKDIR /build
RUN git clone --depth=1 https://gitlab.isc.org/isc-projects/stork -b v2.1.1

WORKDIR /build/stork/backend
ENV GOPATH=/build/go

RUN --mount=type=cache,dst=/build/stork/tools \
    rake build:agent

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

RUN mkdir -p /run/kea /app /etc/apt/keyrings
RUN rm -fv /etc/apt/apt.conf.d/docker-clean
VOLUME /run/kea

RUN  --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt/lists apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates \
      dumb-init \
      ruby \
      iproute2 \
      mysql-client

ARG kea_version 2.7.6-isc20250128083638
COPY kea-dev.asc /etc/apt/keyrings/kea-dev.asc
RUN echo "deb [signed-by=/etc/apt/keyrings/kea-dev.asc] https://dl.cloudsmith.io/public/isc/kea-dev/deb/ubuntu noble main" > /etc/apt/sources.list.d/kea.list
RUN echo "Package: src:isc-kea\nPin: version ${kea_version}\nPin-Priority: 999" > /etc/apt/preferences.d/pin-kea
RUN  --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt/lists apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      isc-kea-dhcp4-server \
      isc-kea-mysql \
      isc-kea-ctrl-agent \
      isc-kea-admin

COPY --from=build-healthz /app/bin/healthz /app/healthzd
COPY --from=build-stork /build/go/bin/stork-agent /app/stork-agent
COPY run.sh /app/run.sh
COPY choose_dhcp_server_id.rb /app/choose_dhcp_server_id.rb
COPY --from=config /app/kea-ctrl-agent.json /app/kea-ctrl-agent.json

RUN kea-ctrl-agent -t /app/kea-ctrl-agent.json

CMD /app/run.sh
