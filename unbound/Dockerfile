FROM public.ecr.aws/docker/library/golang:1.26-trixie as build-exporter

RUN go install github.com/letsencrypt/unbound_exporter@01314cb6b51ed429f3e583d26b41d37754483084

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
