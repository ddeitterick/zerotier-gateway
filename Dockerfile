FROM alpine:3.14.1 as builder

ARG ZT_COMMIT=eac56a2e25bbd27f77505cbd0c21b86abdfbd36b

RUN apk add --update alpine-sdk linux-headers \
  && git clone --quiet https://github.com/zerotier/ZeroTierOne.git /src \
  && git -C src reset --quiet --hard ${ZT_COMMIT} \
  && cd /src \
  && make ZT_DEBUG=1 -f make-linux.mk

FROM alpine:3.14.1
LABEL version="1.8.4"
LABEL description="ZeroTier One as Docker Image"

RUN apk add --update --no-cache libc6-compat libstdc++ bash iptables

EXPOSE 9993/udp

COPY --from=builder /src/zerotier-one /usr/sbin/
RUN mkdir -p /var/lib/zerotier-one \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-idtool \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-cli

COPY main.sh /usr/sbin/main.sh
RUN chmod 0755 /usr/sbin/main.sh

ENTRYPOINT ["/usr/sbin/main.sh"]
