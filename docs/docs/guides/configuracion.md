# Configuración

Todo se configura por variables de entorno (ConfigMap en AKS, `.env` en local). Las credenciales
**no** son variables: son ficheros (ver [Secretos](secretos.md)).

## Túnel

| Variable | Defecto | Descripción |
|---|---|---|
| `TUNNEL_ENABLED` | `true` | Abre el túnel al arrancar |
| `TUNNEL_REMOTE_HOST` | — **(obligatoria)** | IP/FQDN del OnPrem |
| `TUNNEL_REMOTE_USER` | `aks-nemesis` | Usuario SSH en el OnPrem |
| `TUNNEL_REMOTE_PORT` | `443` | Puerto del sshd OnPrem |
| `TUNNEL_FORWARDS` | `0.0.0.0:3000:127.0.0.1:3000` | Uno o varios `-L`, separados por espacio |
| `TUNNEL_VERBOSITY` | `3` | `0`–`3` → nada, `-v`, `-vv`, `-vvv` |
| `TUNNEL_SERVER_ALIVE_INTERVAL` | `30` | `ServerAliveInterval` (s) |
| `TUNNEL_SERVER_ALIVE_COUNT_MAX` | `3` | `ServerAliveCountMax` |
| `TUNNEL_CONNECT_TIMEOUT` | `15` | `ConnectTimeout` (s) |
| `TUNNEL_BACKOFF_MIN` / `_MAX` | `2` / `60` | Backoff de reconexión (s) |
| `TUNNEL_MAX_RETRIES` | vacío (∞) | Sale con error tras N intentos (deja que Kubernetes reinicie) |
| `TUNNEL_HEALTH_PATH` | vacío (AKS: `/v1/models`) | Ruta HTTP para `healthcheck.sh --deep` |
| `TUNNEL_EXTRA_SSH_OPTS` | vacío | Opciones extra para `ssh`, p. ej. `-o Compression=yes` |

## Secretos y rutas

| Variable | Defecto | Descripción |
|---|---|---|
| `TUNNEL_SECRETS_DIR` | `/run/secrets/tunnel` | Dónde se montan llave/passphrase/known_hosts |
| `TUNNEL_KEY_FILE_NAME` | `id_rsa_ed25519` | Nombre del fichero de la llave |
| `TUNNEL_RUNTIME_DIR` | `/run/tunnel` | tmpfs de trabajo (agente, pública, known_hosts) |
| `TUNNEL_KEY_PASSPHRASE` | — | *Fallback* desaconsejado si no hay fichero `passphrase` |

## Sandbox

| Variable | Defecto | Descripción |
|---|---|---|
| `SSHD_ENABLED` | `false` (imagen) / `true` (compose) | Arranca el sshd de pruebas en `:22` |
| `SANDBOX_TESTER_PASSWORD` | `tester123` | Password de `tester` |
| `SANDBOX_ROOT_PASSWORD` | `root123` | Password de `root` |

## Varios servicios por el mismo túnel

```env
TUNNEL_FORWARDS=0.0.0.0:3000:127.0.0.1:3000 0.0.0.0:8080:127.0.0.1:8080
```

Añade el puerto al `Service` y al `containerPort`, y — si usas NetworkPolicy — a sus reglas, y
autoriza el destino en el OnPrem (`PermitOpen 127.0.0.1:3000 127.0.0.1:8080`). El healthcheck comprueba
todos los listeners; el `--deep` sólo el primero.
