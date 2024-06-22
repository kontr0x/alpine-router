FROM alpine:latest
WORKDIR ./

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
    tshark \
    openvpn \
    wireguard-tools \
    && rm -rf /var/cache/apk/*

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

# DEBUG temporarily set to true until the issue is resolved
ENV DEBUG="true"
ENV VPN_TYPE=""
ENV VPN_CONFIG=""
ENV OPENVPN_USER=""
ENV OPENVPN_PASS=""
ENV OPENVPN_AUTH_FILE=""

ENTRYPOINT ["/entrypoint.sh"]
