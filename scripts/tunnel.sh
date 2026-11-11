#!/bin/bash
# =============================================================================
# nexbridge · tunnel.sh
#   Mantiene abierto el túnel SSH OnPrem → AKS. Equivale a:
#
#     ssh -vvv -NT \
#       -o ExitOnForwardFailure=yes \
#       -o ServerAliveInterval=30 \
#       -o ServerAliveCountMax=3 \
#       -p 443 \
#       -i id_rsa_ed25519 \
#       -L 0.0.0.0:3000:127.0.0.1:3000 \
#       aks-nemesis@<ONPREM_HOST>
#
#   con reconexión automática (backoff exponencial) y la llave cargada en
#   ssh-agent: la passphrase y la llave descifrada nunca quedan en disco.
#   Se ejecuta como usuario `tunnel` (sin privilegios).
# =============================================================================
set -euo pipefail

log() { printf '%s [tunnel] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

RUNTIME_DIR="${TUNNEL_RUNTIME_DIR:-/run/tunnel}"
REMOTE_HOST="${TUNNEL_REMOTE_HOST:?TUNNEL_REMOTE_HOST requerido}"
REMOTE_USER="${TUNNEL_REMOTE_USER:-aks-nemesis}"
REMOTE_PORT="${TUNNEL_REMOTE_PORT:-443}"
FORWARDS="${TUNNEL_FORWARDS:-0.0.0.0:3000:127.0.0.1:3000}"
VERBOSITY="${TUNNEL_VERBOSITY:-3}"
ALIVE_INTERVAL="${TUNNEL_SERVER_ALIVE_INTERVAL:-30}"
ALIVE_COUNT="${TUNNEL_SERVER_ALIVE_COUNT_MAX:-3}"
CONNECT_TIMEOUT="${TUNNEL_CONNECT_TIMEOUT:-15}"
BACKOFF_MIN="${TUNNEL_BACKOFF_MIN:-2}"
BACKOFF_MAX="${TUNNEL_BACKOFF_MAX:-60}"
STRICT="${TUNNEL_STRICT_HOST_KEY:-accept-new}"
EXTRA_OPTS="${TUNNEL_EXTRA_SSH_OPTS:-}"

KEY="${RUNTIME_DIR}/id_key"
PASSFILE="${RUNTIME_DIR}/passphrase"
export HOME="$RUNTIME_DIR"

SSH_PID=""
AGENT_PID=""

cleanup() {
    log "señal recibida, cerrando túnel"
    [ -n "$SSH_PID" ] && kill "$SSH_PID" 2>/dev/null || true
    [ -n "$AGENT_PID" ] && kill "$AGENT_PID" 2>/dev/null || true
    exit 0
}
trap cleanup TERM INT

# --- 1. ssh-agent + llave ----------------------------------------------------
start_agent() {
    eval "$(ssh-agent -s -a "${RUNTIME_DIR}/agent.sock")" >/dev/null
    AGENT_PID="$SSH_AGENT_PID"

    if [ -s "$PASSFILE" ]; then
        export TUNNEL_PASSPHRASE_FILE="$PASSFILE"
        SSH_ASKPASS=/usr/local/bin/askpass.sh SSH_ASKPASS_REQUIRE=force DISPLAY=none \
            timeout 20 ssh-add "$KEY" </dev/null >/dev/null 2>&1 \
            || { log "ERROR: no se pudo descifrar la llave (¿passphrase incorrecta?)"; exit 1; }
    else
        SSH_ASKPASS=/bin/false SSH_ASKPASS_REQUIRE=force timeout 20 ssh-add "$KEY" </dev/null >/dev/null 2>&1 \
            || { log "ERROR: la llave requiere passphrase y no se ha proporcionado"; exit 1; }
    fi

    # Pública para IdentitiesOnly; borramos privada y passphrase del disco.
    ssh-add -L | head -n1 > "${KEY}.pub"
    rm -f "$KEY" "$PASSFILE" "${PASSFILE}.used"
    unset TUNNEL_PASSPHRASE_FILE
    log "llave cargada en ssh-agent ($(ssh-add -l | awk '{print $2}'))"
}

# --- 2. comando ssh ----------------------------------------------------------
build_cmd() {
    CMD=(ssh -NT)
    if [ "$VERBOSITY" -gt 0 ] 2>/dev/null; then
        CMD+=("-$(printf 'v%.0s' $(seq 1 "$VERBOSITY"))")
    fi
    CMD+=(
        -o ExitOnForwardFailure=yes
        -o ServerAliveInterval="$ALIVE_INTERVAL"
        -o ServerAliveCountMax="$ALIVE_COUNT"
        -o ConnectTimeout="$CONNECT_TIMEOUT"
        -o StrictHostKeyChecking="$STRICT"
        -o UserKnownHostsFile="${RUNTIME_DIR}/known_hosts"
        -o IdentitiesOnly=yes
        -o IdentityAgent="$SSH_AUTH_SOCK"
        -o BatchMode=yes
        -o TCPKeepAlive=yes
        -p "$REMOTE_PORT"
        -i "${KEY}.pub"
    )
    local fwd
    for fwd in $FORWARDS; do CMD+=(-L "$fwd"); done
    # shellcheck disable=SC2206
    [ -n "$EXTRA_OPTS" ] && CMD+=($EXTRA_OPTS)
    CMD+=("${REMOTE_USER}@${REMOTE_HOST}")
}

# --- 3. bucle con reconexión -------------------------------------------------
main() {
    start_agent
    build_cmd
    log "destino ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT} · forwards: ${FORWARDS}"

    local backoff="$BACKOFF_MIN" attempt=0 started rc
    while true; do
        attempt=$((attempt + 1))
        log "abriendo túnel (intento ${attempt})"
        started=$(date +%s)
        "${CMD[@]}" &
        SSH_PID=$!
        set +e; wait "$SSH_PID"; rc=$?; set -e
        SSH_PID=""

        # Si la sesión aguantó más de 5 min se considera sana: reset backoff.
        if [ $(( $(date +%s) - started )) -gt 300 ]; then backoff="$BACKOFF_MIN"; fi
        log "túnel cerrado (rc=${rc}); reintento en ${backoff}s"
        sleep "$backoff" & wait $! || true
        backoff=$(( backoff * 2 )); [ "$backoff" -gt "$BACKOFF_MAX" ] && backoff="$BACKOFF_MAX"

        if [ -n "${TUNNEL_MAX_RETRIES:-}" ] && [ "$attempt" -ge "$TUNNEL_MAX_RETRIES" ]; then
            log "ERROR: alcanzado TUNNEL_MAX_RETRIES=${TUNNEL_MAX_RETRIES}"; exit 1
        fi
    done
}

main
