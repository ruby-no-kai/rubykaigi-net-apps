FROM public.ecr.aws/docker/library/golang:1.26-trixie as build-exporter

RUN go install github.com/hanazuki/unbound_exporter@8ff4abc0f6e4b05e3bb4073dda1227cdaffdefcc

###

FROM public.ecr.aws/ubuntu/ubuntu:24.04

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends unbound dns-root-data dumb-init && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build-exporter /go/bin/unbound_exporter /usr/local/bin/

RUN /usr/libexec/unbound-helper root_trust_anchor_update

COPY entrypoint.sh /
RUN chmod +x entrypoint.sh

ENTRYPOINT ["dumb-init", "/entrypoint.sh"]
