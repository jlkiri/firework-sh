FROM scratch

ADD rootfs /

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
    localepurge \
    dnsutils \ 
    iputils-ping \
    cpu-checker \
    wireguard \
    && rm -rf /var/lib/apt/lists/*

# # Install Docker
# RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
#     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
#     apt-get update && \
#     apt-get install -y docker-ce docker-ce-cli containerd.io

# COPY config/docker/docker.service /etc/systemd/system/docker.service.d/override.conf

# # Needed to make Docker work
# RUN update-alternatives --set iptables /usr/sbin/iptables-legacy

# Generate guest SSH keys
RUN ssh-keygen -A

# configure sshd
RUN sed -i 's/^#\(PermitRootLogin\) .*/\1 yes/' /etc/ssh/sshd_config
RUN sed -i 's/^#\(PasswordAuthentication\) .*/\1 no/' /etc/ssh/sshd_config

RUN apt autoremove -y
RUN apt clean
RUN apt autoclean
RUN localepurge

# RUN systemctl daemon-reload

# COPY config/dnsmasq@.service /etc/systemd/system/dnsmasq@.service
# COPY config/local.conf /etc/dnsmasq.d/local.conf

# RUN systemctl disable systemd-resolved
# RUN systemctl enable docker
# RUN systemctl enable dnsmasq@local
# RUN systemctl enable consul
