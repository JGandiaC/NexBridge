# syntax=docker/dockerfile:1.7
# =============================================================================
# NexBridge
#   Puente SSH entre un servidor OnPrem y un clúster AKS.
#   - Proceso principal: túnel SSH local-forward (ssh -L) con reconexión.
#   - Opcional: servidor SSH de sandbox (heredado) para pruebas.
# =============================================================================
FROM alpine:3.19

ARG VERSION=1.0.0
LABEL org.opencontainers.image.title="NexBridge" \
      org.opencontainers.image.description="Túnel SSH OnPrem → AKS para exponer servicios OnPrem (IA local compatible OpenAI) dentro del clúster" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="Proprietary"

RUN apk add --no-cache \
      openssh-server \
      openssh-client \
      openssl \
      bash \
      curl \
      netcat-openbsd \
      iproute2 \
      bind-tools \
      tcpdump \
      tini \
      su-exec \
      tzdata

# --- Sandbox sshd (comportamiento heredado) ---------------------------------
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
    mkdir -p /home/tester/.ssh && \
    chmod 700 /home/tester/.ssh && \
    chown tester:tester /home/tester/.ssh

# --- Usuario sin privilegios que ejecuta el túnel ----------------------------
RUN addgroup -S -g 10001 tunnel && \
    adduser -S -D -H -u 10001 -G tunnel -s /sbin/nologin tunnel

COPY --chmod=0755 entrypoint.sh /entrypoint.sh
COPY --chmod=0755 scripts/tunnel.sh scripts/askpass.sh scripts/healthcheck.sh /usr/local/bin/

ENV VERSION=${VERSION} \
    TUNNEL_ENABLED=true \
    SSHD_ENABLED=false \
    TUNNEL_REMOTE_USER=aks-nemesis \
    TUNNEL_REMOTE_PORT=443 \
    TUNNEL_FORWARDS="0.0.0.0:3000:127.0.0.1:3000" \
    TUNNEL_VERBOSITY=3 \
    TUNNEL_SECRETS_DIR=/run/secrets/tunnel \
    TUNNEL_RUNTIME_DIR=/run/tunnel \
    TZ=UTC

EXPOSE 22 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]
