FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/golang:1.22-bookworm as build

ENV GOOS=linux
ENV GOARCH=arm64
ENV CGO_ENABLED=0

RUN go install github.com/dmachard/go-dnscollector@25b9b58c2f508719d6b9f7d5f58f753028fcc1f2

###

FROM public.ecr.aws/ubuntu/ubuntu:24.04

COPY --from=build /go/bin/linux_arm64/go-dnscollector /usr/local/bin/dnscollector
COPY --chmod=0755 entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
