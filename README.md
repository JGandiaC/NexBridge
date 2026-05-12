# hola-connect

Sandbox ligero de servidor SSH para pruebas de conectividad, túneles y autenticación con llaves.

## Requisitos

- Docker + Docker Compose

## Uso rápido

```bash
make keys        # Generar par de llaves SSH
make build       # Construir imagen Docker
make run         # Iniciar contenedor en segundo plano
make ssh         # Conectar vía SSH (password: tester123)
```

## Credenciales

| Usuario  | Password   |
|----------|-----------|
| `tester` | `tester123` |
| `root`   | `root123`   |

```bash
ssh tester@localhost -p 2222
```

## Comandos disponibles

| Comando         | Descripción                               |
|-----------------|-------------------------------------------|
| `make build`    | `docker compose build`                    |
| `make run`      | `docker compose up -d`                    |
| `make ssh`      | `ssh tester@localhost -p 2222`            |
| `make keys`     | Generar llaves SSH en `./keys/`           |
| `make logs`     | Ver logs del contenedor                   |
| `make stop`     | `docker compose down`                     |
| `make clean`    | `docker compose down -v` (borra volúmenes) |

## Autenticación con llaves

```bash
make keys
make run
make ssh   # conecta automáticamente con la llave generada
```

Las llaves se copian a `~/.ssh/authorized_keys` al iniciar el contenedor.

## Herramientas de red incluidas

- `curl`, `nc` (netcat), `ip`, `tcpdump`, `dig`, `nslookup`

## Puertos

- Host `2222` → Contenedor `22`

## Notas

- La verificación de host key está deshabilitada en `ssh_config` para entornos de prueba.
- El contenedor incluye `NET_ADMIN` para experimentar con configuración de red.
