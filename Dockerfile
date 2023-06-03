# syntax=docker/dockerfile:1.3-labs

FROM scratch

ADD rootfs /

WORKDIR /firework

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update && \
    apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    make \
    netcat-traditional \
    dnsutils \ 
    iputils-ping \
    cpu-checker \
    systemd \
    iptables \
    vim \
    dnsmasq
    && rm -rf /var/lib/apt/lists/*

RUN curl -OL https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64 && \
    chmod +x runc.amd64 && \
    mv runc.amd64 /usr/local/bin/runc

RUN curl -OL https://github.com/moby/buildkit/releases/download/v0.11.6/buildkit-v0.11.6.linux-amd64.tar.gz && \
    tar -xvf buildkit-v0.11.6.linux-amd64.tar.gz -C /usr/local

# Generate guest SSH keys
RUN ssh-keygen -A

# RUN update-alternatives --set iptables /usr/sbin/iptables-legacy

# configure sshd
RUN sed -i 's/^#\(PermitRootLogin\) .*/\1 yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\(PasswordAuthentication\) .*/\1 no/' /etc/ssh/sshd_config

COPY <<EOF /etc/systemd/system/buildkitd.service
[Unit]
Description=Buildkit daemon

[Service]
ExecStart=/usr/local/bin/buildkitd

[Install]
WantedBy=multi-user.target
EOF

COPY . .

RUN rm /etc/systemd/system/systemd-resolved.service || true && \
    rm /usr/lib/systemd/system/systemd-resolved.service || true \
    rm /lib/systemd/system/systemd-resolved.service || true