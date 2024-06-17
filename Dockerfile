FROM alpine:latest

# Installing some tools
RUN apk --update add --no-cache tzdata \
    vim \
    curl \
    wget \
    iptables \
    dnsmasq \
    iproute2 \
    tcpdump \
    inetutils-telnet \
    nmap \
    && rm -rf /var/cache/apk/*

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
