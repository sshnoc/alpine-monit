# https://hangarau.space/using-supervisord-as-the-init-process-of-a-docker-container/
FROM alpine:3.18 AS builder

RUN mkdir /usr/local/src && \
    apk update && apk upgrade && \
    apk add  --no-cache binutils git make clang gcc musl-dev
WORKDIR /usr/local/src
RUN git clone https://github.com/dennypage/dpinger.git
RUN cd dpinger && make

FROM alpine:3.18
LABEL maintainer="sshnoc.com"

ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM

RUN echo "I'm building for $TARGETPLATFORM $TARGETARCH $BUILDPLATFORM"

COPY --from=builder /usr/local/src/dpinger/dpinger /usr/bin/dpinger

COPY ./etc/monitrc /etc/monitrc
# COPY ./*.py /
COPY ./*.sh /

# mkdir /etc/monit.d && \
RUN apk update && apk upgrade && \
    apk add --no-cache tini ca-certificates rsyslog monit ssmtp && \
    apk add --no-cache wireguard-tools-wg-quick fping screen && \
    apk add --no-cache dropbear && \
    mkdir /etc/monit.d && \
    mkdir /etc/wireguard && \
    chmod +x /*.sh && \
    chmod go-rwx /etc/monitrc && \
    mkdir -p /var/run/monit/events && \
    rm -rf /var/cache/apk/*

COPY ./etc/monit.d/*.conf /etc/monit.d/
COPY ./etc/rsyslog.conf /etc/rsyslog.conf

VOLUME [ "/var/run/monit" ]

EXPOSE 2812/tcp
# Define default command.
ENTRYPOINT ["/sbin/tini", "-v", "--"]
# CMD [ "/usr/bin/monit", "-I" ]
CMD [ "/init.sh" ]

# TODO
# Start crond
# Send status emails
