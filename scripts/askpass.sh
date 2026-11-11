#!/bin/sh
# SSH_ASKPASS helper: entrega la passphrase de la llave a ssh-add sin TTY.
# Lee de un fichero (nunca de argumentos ni de variables visibles en `ps`).
# Un solo uso: si ssh-add vuelve a preguntar (passphrase incorrecta) devuelve
# vacío y ssh-add aborta, en lugar de reintentar en bucle.
set -eu
f="${TUNNEL_PASSPHRASE_FILE:?}"
marker="${f}.used"
[ -e "$marker" ] && exit 1
: > "$marker"
exec cat "$f"
