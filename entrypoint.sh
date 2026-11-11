#!/bin/bash
# =============================================================================
# tunnel-connect · entrypoint
#   1. (opcional) prepara y arranca el sshd de sandbox       SSHD_ENABLED=true
#   2. prepara las credenciales del túnel desde los secrets  TUNNEL_ENABLED=true
#   3. lanza el túnel como usuario sin privilegios (PID principal)
# Si se pasa un comando (docker run ... <cmd>) se ejecuta ese en su lugar.
# =============================================================================
set -euo pipefail

log() { printf '%s [entrypoint] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

TUNNEL_ENABLED="${TUNNEL_ENABLED:-true}"
SSHD_ENABLED="${SSHD_ENABLED:-false}"
SECRETS_DIR="${TUNNEL_SECRETS_DIR:-/run/secrets/tunnel}"
RUNTIME_DIR="${TUNNEL_RUNTIME_DIR:-/run/tunnel}"
KEY_FILE_NAME="${TUNNEL_KEY_FILE_NAME:-id_rsa_ed25519}"

# -----------------------------------------------------------------------------
# Sandbox sshd (comportamiento heredado de tunnel-connect 0.1.x)
# -----------------------------------------------------------------------------
setup_sandbox() {
    echo "tester:${SANDBOX_TESTER_PASSWORD:-tester123}" | chpasswd
    echo "root:${SANDBOX_ROOT_PASSWORD:-root123}" | chpasswd

    if [ -d /keys ]; then
        mkdir -p /home/tester/.ssh
        for f in /keys/*.pub; do
            [ -f "$f" ] && cat "$f" >> /home/tester/.ssh/authorized_keys
        done
        for f in /keys/id_*; do
            if [ -f "$f" ] && [[ "$(basename "$f")" != *.pub ]]; then
                cp "$f" /home/tester/.ssh/
                chmod 600 "/home/tester/.ssh/$(basename "$f")"
            fi
        done
        [ -f /home/tester/.ssh/authorized_keys ] && chmod 600 /home/tester/.ssh/authorized_keys
        # El config se monta read-only; ignoramos errores de chown sobre él
        chown -R tester:tester /home/tester/.ssh 2>/dev/null || true
    fi

    log "sandbox sshd → puerto 22 (usuario: tester)"
}

start_sandbox_bg() { setup_sandbox; /usr/sbin/sshd -e; }

# -----------------------------------------------------------------------------
# Credenciales del túnel
#   Los secrets llegan montados en solo lectura (K8s Secret / Docker secret /
#   Azure Key Vault CSI). Se copian a un directorio en memoria, propiedad del
#   usuario `tunnel`, con los permisos que exige OpenSSH. tunnel.sh carga la
#   llave en ssh-agent y borra las copias del disco.
# -----------------------------------------------------------------------------
setup_tunnel_credentials() {
    local key_src="${SECRETS_DIR}/${KEY_FILE_NAME}"
    local pass_src="${SECRETS_DIR}/passphrase"
    local kh_src="${SECRETS_DIR}/known_hosts"

    [ -n "${TUNNEL_REMOTE_HOST:-}" ] || die "TUNNEL_REMOTE_HOST no definido (IP/host del servidor OnPrem)"
    [ -r "$key_src" ] || die "llave privada no encontrada en ${key_src}"

    install -d -m 0700 -o tunnel -g tunnel "$RUNTIME_DIR"
    install -m 0600 -o tunnel -g tunnel "$key_src" "${RUNTIME_DIR}/id_key"

    if [ -r "$pass_src" ]; then
        install -m 0400 -o tunnel -g tunnel "$pass_src" "${RUNTIME_DIR}/passphrase"
    elif [ -n "${TUNNEL_KEY_PASSPHRASE:-}" ]; then
        log "AVISO: passphrase leída de variable de entorno; preferible montarla como fichero"
        ( umask 0277; printf '%s' "$TUNNEL_KEY_PASSPHRASE" > "${RUNTIME_DIR}/passphrase" )
        chown tunnel:tunnel "${RUNTIME_DIR}/passphrase"
    else
        log "AVISO: sin passphrase; se asume llave sin cifrar"
    fi
    unset TUNNEL_KEY_PASSPHRASE

    if [ -s "$kh_src" ]; then
        install -m 0644 -o tunnel -g tunnel "$kh_src" "${RUNTIME_DIR}/known_hosts"
        export TUNNEL_STRICT_HOST_KEY=yes
    else
        log "AVISO: sin known_hosts; se usará StrictHostKeyChecking=accept-new (TOFU)"
        install -m 0644 -o tunnel -g tunnel /dev/null "${RUNTIME_DIR}/known_hosts"
        export TUNNEL_STRICT_HOST_KEY=accept-new
    fi
}

banner() {
    log "=== tunnel-connect ${VERSION:-} ==="
    log "  túnel:   ${TUNNEL_ENABLED}  → ${TUNNEL_REMOTE_USER:-aks-nemesis}@${TUNNEL_REMOTE_HOST:-?}:${TUNNEL_REMOTE_PORT:-443}"
    log "  forward: ${TUNNEL_FORWARDS:-}"
    log "  sandbox: ${SSHD_ENABLED}"
}

main() {
    # Comando explícito → modo "herramienta" (debug, shell, etc.)
    if [ "$#" -gt 0 ]; then
        [ "$SSHD_ENABLED" = "true" ] && start_sandbox_bg
        exec "$@"
    fi

    banner

    if [ "$TUNNEL_ENABLED" = "true" ]; then
        [ "$SSHD_ENABLED" = "true" ] && start_sandbox_bg
        setup_tunnel_credentials
        exec su-exec tunnel:tunnel /usr/local/bin/tunnel.sh
    fi

    [ "$SSHD_ENABLED" = "true" ] || die "TUNNEL_ENABLED y SSHD_ENABLED desactivados: nada que ejecutar"
    setup_sandbox
    log "solo sandbox: sshd en primer plano"
    exec /usr/sbin/sshd -D -e
}

main "$@"
