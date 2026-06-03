# UniFi Controller - Ubuntu 22.04 (Jammy)
# Based on: https://gist.github.com/melchoy/d0cfd6af5a4e39abfcc6c2cd8dacd8ba
FROM ubuntu:22.04

# -- Environment --------------------------------------------------------------─
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# -- APT tweaks (match the original script) ------------------------------------
RUN mkdir -p /etc/apt/apt.conf.d /etc/apt/trusted.gpg.d /etc/apt/sources.list.d && \
    # Disable phased updates
    printf '// Disable phased updates\nAPT::Machine-ID "aaaabbbbccccddddeeeeffff";\nUpdate-Manager::Always-Include-Phased-Updates;\nAPT::Get::Always-Include-Phased-Updates: True;\n' \
        > /etc/apt/apt.conf.d/99custom-disable-phased-updates && \
    # Disable install of recommended/suggested packages
    printf '// Disable recommended packages\nAPT::Install-Recommends "false";\n' \
        > /etc/apt/apt.conf.d/99custom-no-install-recommends && \
    # Suppress needrestart interactive prompts
    ( test -f /etc/needrestart/needrestart.conf && \
      sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" \
          /etc/needrestart/needrestart.conf || true )

# -- Base packages ------------------------------------------------------------─
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y \
        binutils \
        coreutils \
        curl \
        wget \
        lsb-release \
        ca-certificates \
        apt-transport-https \
        software-properties-common \
        gnupg \
        tzdata \
        vim-tiny \
        net-tools \
        dnsutils \
        mtr-tiny && \
    rm -rf /var/lib/apt/lists/*

# -- Timezone ------------------------------------------------------------------
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime && \
    echo "UTC" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# -- OpenJDK 17 (required for UniFi 7.5+) ------------------------------------─
RUN apt-get update -y && \
    apt-get install -y openjdk-17-jre-headless && \
    rm -rf /var/lib/apt/lists/*

# -- libssl1.1 (UniFi / MongoDB 4.4 dependency on Jammy) ----------------------
# Pull from Ubuntu 20.04 focal-security — the package was removed from Jammy.
RUN echo "deb http://security.ubuntu.com/ubuntu focal-security main" \
        > /etc/apt/sources.list.d/focal-security.list && \
    apt-get update -y && \
    apt-get install -y libssl1.1 && \
    rm /etc/apt/sources.list.d/focal-security.list && \
    rm -rf /var/lib/apt/lists/*

# -- UniFi APT repo ------------------------------------------------------------
RUN wget -qO /etc/apt/trusted.gpg.d/unifi-repo.gpg \
        https://dl.ui.com/unifi/unifi-repo.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/unifi-repo.gpg] \
https://www.ui.com/downloads/unifi/debian stable ubiquiti" \
        > /etc/apt/sources.list.d/ubnt-unifi-stable.list

# -- MongoDB 4.4 APT repo ------------------------------------------------------
# UniFi 7.5.x requires MongoDB >= 3.6 and < 5.0; 4.4 is the safest choice.
# The repo targets Ubuntu focal (20.04) — the packages are compatible with Jammy.
RUN wget -qO- https://www.mongodb.org/static/pgp/server-4.4.asc | \
        gpg --dearmor \
            -o /etc/apt/trusted.gpg.d/mongodb-org-server-4.4-archive-keyring.gpg && \
    echo "deb [arch=amd64,arm64 signed-by=/etc/apt/trusted.gpg.d/mongodb-org-server-4.4-archive-keyring.gpg] \
https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" \
        > /etc/apt/sources.list.d/mongodb-org-4.4.list

# -- Install MongoDB server + UniFi --------------------------------------------
RUN apt-get update -y && \
    apt-get install -y mongodb-org-server unifi && \
    rm -rf /var/lib/apt/lists/*

# -- MongoDB data directory ----------------------------------------------------
RUN mkdir -p /data/db && \
    chown -R mongodb:mongodb /data/db

# -- UniFi ports --------------------------------------------------------------─
# Device communication  : 8080/tcp
# HTTPS UI              : 8443/tcp
# STUN                  : 3478/udp
# Remote syslog         : 5514/udp
# Throughput test       : 6789/tcp
# L2 device discovery   : 10001/udp
# UPnP / SSDP           : 1900/udp
# Guest portal HTTP/S   : 80/tcp, 443/tcp
EXPOSE 8080 8443 6789 80 443
EXPOSE 3478/udp 5514/udp 10001/udp 1900/udp

# -- Startup ------------------------------------------------------------------─
# Use a small shell script so signals propagate cleanly and we can tail the
# UniFi log rather than /dev/null for easier debugging.
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

CMD ["/docker-entrypoint.sh"]
