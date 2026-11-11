#!/bin/bash
# Prepara ./secrets/ para docker compose y `make k8s-secret`.
# Copia la llave privada, pide la passphrase sin eco y deja todo en 0600.
set -euo pipefail

DIR="${1:-./secrets}"
KEY_NAME="${2:-id_rsa_ed25519}"

umask 077
mkdir -p "$DIR"

if [ ! -f "$DIR/$KEY_NAME" ]; then
    read -r -p "Ruta de la llave privada para el OnPrem [$HOME/.ssh/$KEY_NAME]: " src
    src="${src:-$HOME/.ssh/$KEY_NAME}"
    [ -f "$src" ] || { echo "No existe: $src" >&2; exit 1; }
    cp "$src" "$DIR/$KEY_NAME"
fi

if [ ! -s "$DIR/passphrase" ]; then
    read -r -s -p "Passphrase de la llave (no se mostrará): " pass; echo
    printf '%s' "$pass" > "$DIR/passphrase"
    unset pass
fi

# Valida que la passphrase descifra la llave
if ! ssh-keygen -y -P "$(cat "$DIR/passphrase")" -f "$DIR/$KEY_NAME" >/dev/null 2>&1; then
    echo "ERROR: la passphrase no descifra la llave" >&2
    exit 1
fi

[ -f "$DIR/known_hosts" ] || : > "$DIR/known_hosts"
chmod 600 "$DIR"/*

echo "OK → $DIR"
ls -l "$DIR"
[ -s "$DIR/known_hosts" ] || echo "Sugerencia: make known-hosts TUNNEL_REMOTE_HOST=<ip-onprem> para fijar la host key"
