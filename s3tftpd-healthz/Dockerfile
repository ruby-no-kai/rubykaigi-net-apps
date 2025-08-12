FROM public.ecr.aws/docker/library/rust:1.85-slim-trixie as build

COPY . /build/s3tftpd-healthz
WORKDIR /build/s3tftpd-healthz

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/build/s3tftpd-healthz/target \
    cargo install --path . --root /app --locked

FROM public.ecr.aws/docker/library/debian:trixie-slim

COPY --from=build /app /app
CMD ["/app/bin/s3tftpd-healthz"]
