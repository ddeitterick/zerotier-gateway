ARG ALPINE_IMAGE=alpine
ARG ALPINE_VERSION=latest
ARG ZT_COMMIT=327eb9013b39809835a912c9117a0b9669f4661f
ARG ZT_VERSION=1.12.2

FROM ${ALPINE_IMAGE}:${ALPINE_VERSION} as builder

ARG ZT_COMMIT

RUN apk add --update alpine-sdk linux-headers cargo openssl-dev \
  && git clone --quiet https://github.com/zerotier/ZeroTierOne.git /src \
  && git -C src reset --quiet --hard ${ZT_COMMIT} \
  && cd /src \
  && make -f make-linux.mk

FROM ${ALPINE_IMAGE}:${ALPINE_VERSION}

ARG ZT_VERSION

LABEL org.opencontainers.image.title="zerotier-gateway" \
      org.opencontainers.image.version="${ZT_VERSION}" \
      org.opencontainers.image.description="ZeroTier One as Docker Image" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/ddeitterick/zerotier-gateway"

COPY --from=builder /src/zerotier-one /usr/sbin/

RUN apk add --no-cache --purge --clean-protected --update libc6-compat libstdc++ bash iptables iptables-legacy iproute2\
  && mkdir -p /var/lib/zerotier-one \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-idtool \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-cli \
  && rm -rf /var/cache/apk/*

EXPOSE 9993/udp

COPY main.sh /usr/sbin/main.sh
RUN chmod 0755 /usr/sbin/main.sh

ENTRYPOINT ["/usr/sbin/main.sh"]
