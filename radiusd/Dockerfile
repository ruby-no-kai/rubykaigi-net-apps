FROM public.ecr.aws/ubuntu/ubuntu:22.04

ARG FR_VERSION=3.0.26~dfsg~git20220223.1.00ed0241fa-0ubuntu3.2

RUN mkdir -p /etc/freeradius/3.0/certs && touch /etc/freeradius/3.0/certs/dh
RUN apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
      freeradius=${FR_VERSION} \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN rm /etc/freeradius/3.0/sites-enabled/*
COPY --chown=freerad:freerad raddb/ /etc/freeradius/3.0/
COPY --chown=freerad:freerad dummycert /secrets/tls-cert
COPY run.sh /run.sh

RUN find /etc/freeradius/3.0 /secrets/tls-cert \( -type f -exec chmod 0640 {} + \) -o \( -type d -exec chmod 0750 {} + \)

RUN ls -Rla /etc/freeradius/3.0
RUN ls -la /secrets/tls-cert

USER freerad
RUN /usr/sbin/freeradius -f -Cx -lstdout

USER root
RUN rm -rf /secrets

USER freerad
EXPOSE 1812/tcp 1812/udp
EXPOSE 18121/tcp 18121/udp
CMD ["/run.sh"]
