ARG BASE=public.ecr.aws/ubuntu/ubuntu:24.04

ARG DNSDIST_VERSION=1.9.8
# dnsdist=1.9.8 does not support quiche>=0.23
ARG QUICHE_VERSION=0.22.0
ARG QUICHE_SHA256SUM=0af8744b07038ee4af8cdb94dd4c11f1a730001944a0ef2f3f03e63715b15268

###

FROM $BASE AS download-base
WORKDIR /download

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg

###

FROM download-base AS download-dnsdist

ARG DNSDIST_VERSION
RUN curl -sSf "https://downloads.powerdns.com/releases/dnsdist-${DNSDIST_VERSION}.tar.bz2" -o dnsdist.tar.bz2
RUN curl -sSf "https://downloads.powerdns.com/releases/dnsdist-${DNSDIST_VERSION}.tar.bz2.asc" -o dnsdist.tar.bz2.asc

COPY ./dnsdist.asc ./
RUN gpg --no-default-keyring --keyring dnsdist --import ./dnsdist.asc
RUN gpg --no-default-keyring --keyring dnsdist --verify dnsdist.tar.bz2.asc dnsdist.tar.bz2

###

FROM download-base AS download-quiche

ARG QUICHE_VERSION
ARG QUICHE_SHA256SUM
RUN curl -sSfL "https://github.com/cloudflare/quiche/archive/refs/tags/${QUICHE_VERSION}.tar.gz" -o quiche.tar.gz
RUN echo "${QUICHE_SHA256SUM}  quiche.tar.gz" | sha256sum -c

###

FROM public.ecr.aws/docker/library/rust:1.89.0-trixie AS build-quiche

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      cmake clang

WORKDIR /build

RUN --mount=type=bind,from=download-quiche,source=/download,target=/download \
    tar xf /download/quiche.tar.gz --strip=1
RUN cargo build -p quiche --features=ffi,boringssl-boring-crate --release

ARG QUICHE_VERSION
COPY ./quiche.pc.inc .
RUN sed -e "s|@QUICHE_VERSION@|${QUICHE_VERSION}|" <quiche.pc.inc >quiche.pc

RUN install -D target/release/libquiche.so /opt/quiche/lib/libquiche.so.${QUICHE_VERSION} && \
    install -D -t /opt/quiche/include quiche/include/quiche.h && \
    install -D -t /opt/quiche/lib/pkgconfig quiche.pc && \
    ldconfig -n /opt/quiche/lib

###

FROM $BASE AS build-dnsdist

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential lbzip2 gawk libboost-all-dev libcap-dev libcdb-dev libcrypt-dev libedit-dev libfstrm-dev liblmdb-dev libluajit-5.1-dev libnghttp2-dev libre2-dev libssl-dev

WORKDIR /build

RUN --mount=type=bind,from=download-dnsdist,source=/download,target=/download \
    tar xf /download/dnsdist.tar.bz2 --strip=1

RUN --mount=type=bind,from=build-quiche,source=/opt/quiche,target=/opt/quiche \
    PKG_CONFIG_PATH=/opt/quiche/lib/pkgconfig ./configure --prefix=/opt/dnsdist --enable-dns-over-tls --enable-dns-over-https --enable-dns-over-quic --enable-dns-over-http3 --enable-dnstap --with-gnutls=no --with-re2 --with-cdb

RUN --mount=type=bind,from=build-quiche,source=/opt/quiche,target=/opt/quiche \
    make -j"$(nproc)" install

RUN --mount=type=bind,from=build-quiche,source=/opt/quiche,target=/opt/quiche \
    LD_LIBRARY_PATH=/opt/quiche/lib ldd /opt/dnsdist/bin/dnsdist | \
      gawk 'match($0, /=> (\/lib\/[^ ]+)/, m) { print "/usr"m[1] }' | \
      xargs dpkg -S | gawk 'match($0, /^(.*): /, m) { print m[1] }' >deps.txt

###

FROM $BASE

RUN --mount=type=bind,from=build-dnsdist,source=/build,target=/build \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      dumb-init $(cat /build/deps.txt) && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build-quiche /opt/quiche /opt/quiche
COPY --from=build-dnsdist /opt/dnsdist /opt/dnsdist
RUN ldconfig /opt/*/lib

COPY --chmod=755 entrypoint.sh /

RUN ldd /opt/dnsdist/bin/dnsdist

ENTRYPOINT ["/entrypoint.sh"]
