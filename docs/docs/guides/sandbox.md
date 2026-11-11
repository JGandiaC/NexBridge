# Sandbox SSH

La 0.1.x de tunnel-connect era un **servidor SSH de pruebas** para experimentar con túneles y llaves.
Sigue disponible y es útil para probar el túnel sin depender del OnPrem real.

!!! danger "Sólo para local"
    Usa passwords por defecto y permite login de root. Por eso `SSHD_ENABLED=false` en la imagen y en el
    ConfigMap de AKS. En `docker-compose.yml` está activado.

## Uso

```bash
make keys      # llaves del sandbox en ./keys/
make run
make ssh       # tester@localhost -p 2222 (tester123)
```

| Usuario | Password |
|---|---|
| `tester` | `tester123` (`SANDBOX_TESTER_PASSWORD`) |
| `root` | `root123` (`SANDBOX_ROOT_PASSWORD`) |

Las llaves de `./keys/*.pub` se añaden a `authorized_keys` de `tester` al arrancar. El sshd tiene
`AllowTcpForwarding` y `GatewayPorts` activos, y el contenedor `NET_ADMIN` para experimentar con red.

## Sólo sandbox, sin túnel

```bash
docker run --rm -e TUNNEL_ENABLED=false -e SSHD_ENABLED=true -p 2222:22 tunnel-connect:0.2.0
```

## Simular el OnPrem

Dos contenedores de la misma imagen reproducen el flujo completo: uno como «OnPrem» (sshd en 443 +
un servicio en `127.0.0.1:3000`) y otro como túnel apuntando a él con `TUNNEL_REMOTE_HOST=<nombre>`.
Es así como se validó la 0.2.0 (autenticación con passphrase, reenvío, reconexión, apagado).
