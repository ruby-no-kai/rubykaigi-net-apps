# syntax=docker/dockerfile:1

ARG BASE=public.ecr.aws/ubuntu/ubuntu:24.04

###

FROM public.ecr.aws/docker/library/rust:1.89-slim-trixie as build-healthz

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
RUN git clone --depth=1 https://gitlab.isc.org/isc-projects/stork -b v2.3.0

WORKDIR /build/stork/backend
ENV GOPATH=/build/go

RUN --mount=type=cache,dst=/build/stork/tools \
    rake build:agent

RUN --mount=type=cache,dst=/build/stork/tools \
    ../tools/golang/go/bin/go install ./cmd/stork-agent

###

FROM $BASE as bundler
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ruby \
      ruby-bundler
COPY Gemfile* /app/
ENV BUNDLE_GEMFILE /app/Gemfile
ENV BUNDLE_PATH /app/vendor/bundle
ENV BUNDLE_DEPLOYMENT 1
ENV BUNDLE_JOBS 16
ENV BUNDLE_WITHOUT development:test
RUN bundle install

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
      curl \
      ca-certificates \
      dumb-init \
      ruby ruby-bundler \
      iproute2 \
      mysql-client

ARG kea_version 3.1.1-isc20250825122912
COPY kea-dev.asc /etc/apt/keyrings/kea-dev.asc
RUN echo "deb [signed-by=/etc/apt/keyrings/kea-dev.asc] https://dl.cloudsmith.io/public/isc/kea-dev/deb/ubuntu noble main" > /etc/apt/sources.list.d/kea.list
RUN echo "Package: src:isc-kea\nPin: version ${kea_version}\nPin-Priority: 999" > /etc/apt/preferences.d/pin-kea
RUN  --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt/lists apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      isc-kea-dhcp4-server \
      isc-kea-mysql \
      isc-kea-ctrl-agent \
      isc-kea-admin \
      isc-kea-hooks

COPY --from=build-healthz /app/bin/healthz /app/healthzd
COPY --from=build-stork /build/go/bin/stork-agent /app/stork-agent

COPY Gemfile* /app/
COPY --from=bundler /app/vendor/bundle /app/vendor/bundle
ENV BUNDLE_GEMFILE /app/Gemfile
ENV BUNDLE_PATH /app/vendor/bundle
ENV BUNDLE_DEPLOYMENT 1
ENV BUNDLE_JOBS 16
ENV BUNDLE_WITHOUT development:test

RUN ln -s /usr/lib/$(uname -m)-linux-gnu/kea/hooks /app/kea-hooks
ENV KEA_HOOKS_PATH /app/kea-hooks

COPY run.sh /app/run.sh
COPY db-upgrade.rb /app/db-upgrade.rb
COPY choose_dhcp_server_id.rb /app/choose_dhcp_server_id.rb
COPY --from=config /app/kea-ctrl-agent.json /app/kea-ctrl-agent.json

RUN kea-ctrl-agent -t /app/kea-ctrl-agent.json

CMD /app/run.sh
