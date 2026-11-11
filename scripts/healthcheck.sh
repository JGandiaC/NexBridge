#!/bin/sh
# Healthcheck: el túnel está sano si cada puerto local de TUNNEL_FORWARDS
# acepta conexiones (ssh solo lo abre tras autenticar; con
# ExitOnForwardFailure=yes, si no puede abrirlo, sale).
# Uso: healthcheck.sh            → comprueba listeners
#      healthcheck.sh --deep     → además hace GET ${TUNNEL_HEALTH_PATH} por el túnel
set -eu

if [ "${TUNNEL_ENABLED:-true}" != "true" ]; then
    [ "${SSHD_ENABLED:-false}" = "true" ] && exec nc -z 127.0.0.1 22 2>/dev/null
    exit 0
fi

for fwd in ${TUNNEL_FORWARDS:-0.0.0.0:3000:127.0.0.1:3000}; do
    # formatos: [bind:]port:host:hostport
    port=$(echo "$fwd" | awk -F: '{ print (NF==4 ? $2 : $1) }')
    nc -z -w 2 127.0.0.1 "$port" 2>/dev/null || { echo "puerto ${port} cerrado"; exit 1; }
done

if [ "${1:-}" = "--deep" ] && [ -n "${TUNNEL_HEALTH_PATH:-}" ]; then
    first=$(echo "${TUNNEL_FORWARDS:-0.0.0.0:3000:127.0.0.1:3000}" | awk '{print $1}')
    port=$(echo "$first" | awk -F: '{ print (NF==4 ? $2 : $1) }')
    curl -fsS -m 5 -o /dev/null "http://127.0.0.1:${port}${TUNNEL_HEALTH_PATH}" \
        || { echo "servicio remoto no responde en ${TUNNEL_HEALTH_PATH}"; exit 1; }
fi
exit 0
