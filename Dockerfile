FROM alpine:3.19

RUN apk add --no-cache \
    openssh-server \
    openssh-client \
    openssl \
    bash \
    curl \
    netcat-openbsd \
    iproute2 \
    bind-tools \
    tcpdump

RUN ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N "" && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" && \
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ""

RUN sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#ListenAddress.*/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config && \
    sed -i 's/^#*AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*GatewayPorts.*/GatewayPorts yes/' /etc/ssh/sshd_config && \
    grep -q '^AllowTcpForwarding' /etc/ssh/sshd_config || echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config

RUN adduser -D -s /bin/bash tester && \
    echo "tester:tester123" | chpasswd && \
    echo "root:root123" | chpasswd

RUN mkdir -p /home/tester/.ssh && \
    chmod 700 /home/tester/.ssh && \
    chown tester:tester /home/tester/.ssh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
