ARG ALPINE_IMAGE=alpine
ARG ALPINE_VERSION=latest
ARG ZT_COMMIT=7ea2354540cd891f61d0944ff8a25c53a42bd038
ARG ZT_VERSION=1.8.9

FROM ${ALPINE_IMAGE}:${ALPINE_VERSION} as builder

ARG ZT_COMMIT

RUN apk add --update alpine-sdk linux-headers cargo openssl-dev \
  && git clone --quiet https://github.com/zerotier/ZeroTierOne.git /src \
  && git -C src reset --quiet --hard ${ZT_COMMIT} \
  && cd /src \
  && make ZT_DEBUG=1 -f make-linux.mk

FROM ${ALPINE_IMAGE}:${ALPINE_VERSION}

ARG ZT_VERSION

LABEL org.opencontainers.image.title="zerotier-gateway" \
      org.opencontainers.image.version="${ZT_VERSION}" \
      org.opencontainers.image.description="ZeroTier One as Docker Image" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/ddeitterick/zerotier-gateway"

COPY --from=builder /src/zerotier-one /usr/sbin/

RUN apk add --no-cache --purge --clean-protected --update libc6-compat libstdc++ bash iptables\
  && mkdir -p /var/lib/zerotier-one \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-idtool \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-cli \
  && rm -rf /var/cache/apk/*

EXPOSE 9993/udp

COPY main.sh /usr/sbin/main.sh
RUN chmod 0755 /usr/sbin/main.sh

ENTRYPOINT ["/usr/sbin/main.sh"]
