# Operación y troubleshooting

## Comandos útiles

```bash
make k8s-status
make k8s-logs
kubectl -n nexbridge exec deploy/nexbridge -- healthcheck.sh --deep
kubectl -n nexbridge exec deploy/nexbridge -- ps -o user,args
make k8s-test
```

## Logs

Cada línea propia lleva prefijo `[entrypoint]` o `[tunnel]`; el resto es la salida de `ssh -vvv`.
Con el túnel estable, baja el ruido con `TUNNEL_VERBOSITY=1`.

| Mensaje | Significado | Acción |
|---|---|---|
| `TUNNEL_REMOTE_HOST no definido` | Falta configuración | Revisa el ConfigMap |
| `llave privada no encontrada en …` | Secret no montado o nombre distinto | `kubectl -n nexbridge get secret nexbridge-ssh -o yaml` (claves) / `TUNNEL_KEY_FILE_NAME` |
| `no se pudo descifrar la llave (¿passphrase incorrecta?)` | Passphrase errónea o con `\n` final | Regenera con `make secrets-init` (escribe sin salto de línea) |
| `AVISO: sin known_hosts … (TOFU)` | No se fija la host key | Añade `known_hosts` al Secret |
| `Host key verification failed.` | La host key del OnPrem no coincide | **Para.** Confirma con el equipo OnPrem antes de actualizar `known_hosts` |
| `Permission denied (publickey)` | Pública no autorizada en `aks-nemesis` | Revisa `~aks-nemesis/.ssh/authorized_keys` en el OnPrem |
| `Connection timed out` / `ConnectTimeout` | Sin ruta a `OnPrem:443` | Egress de AKS, NSG, firewall OnPrem, NetworkPolicy |
| `Warning: remote port forwarding failed` / `open failed: administratively prohibited` | `PermitOpen` no incluye el destino | Ajusta `sshd_config` OnPrem |
| `channel N: open failed: connect failed: Connection refused` | Túnel OK, pero la IA local no escucha en `127.0.0.1:3000` | Revisa el servicio en el OnPrem |
| `túnel cerrado (rc=255); reintento en Ns` | Corte; se reconecta solo | Si persiste, ver arriba |

## Pod NotReady pero túnel conectado

La readiness `--deep` hace `GET $TUNNEL_HEALTH_PATH`. Si la IA local tarda o responde no-2xx, el pod sale
del Service. Comprueba:

```bash
kubectl -n nexbridge exec deploy/nexbridge -- curl -sv http://127.0.0.1:3000/v1/models
```

## CrashLoopBackOff

Errores de configuración o credenciales hacen salir al contenedor de inmediato (fallo rápido y visible).
Revisa `kubectl -n nexbridge logs deploy/nexbridge --previous`.

## Depurar con shell

```bash
kubectl -n nexbridge exec -it deploy/nexbridge -- bash
# o, en local:
make shell
```

La imagen incluye `curl`, `nc`, `dig`, `ip`, `tcpdump` para diagnóstico.
