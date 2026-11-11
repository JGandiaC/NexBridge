# Secretos y passphrase

La llave `id_rsa_ed25519` que autoriza a `aks-nemesis` está **cifrada con passphrase**. Para abrir el
túnel sin intervención humana hacen falta las dos cosas, así que ambas se tratan como secreto.

## Qué se guarda

| Clave | Contenido | Obligatorio |
|---|---|---|
| `id_rsa_ed25519` | Llave privada OpenSSH cifrada | Sí |
| `passphrase` | Passphrase, **sin salto de línea final** | Sí (si la llave está cifrada) |
| `known_hosts` | Host key del OnPrem (`[ip]:443 ssh-ed25519 …`) | Recomendado |

El contenedor los espera como **ficheros** en `/run/secrets/tunnel/` (configurable con
`TUNNEL_SECRETS_DIR`; el nombre de la llave con `TUNNEL_KEY_FILE_NAME`).

## Cómo los usa el contenedor

1. **entrypoint** (root) copia los ficheros a `/run/tunnel` — `emptyDir` en **memoria** — con dueño `tunnel` y `0600`.
2. **tunnel.sh** (usuario `tunnel`) arranca `ssh-agent` y ejecuta `ssh-add` con `SSH_ASKPASS_REQUIRE=force`.
   `askpass.sh` entrega la passphrase **leyendo el fichero** — nunca por argumento ni variable visible en `ps`.
3. El askpass es de **un solo uso**: si la passphrase es incorrecta, `ssh-add` falla al primer intento
   y el contenedor sale con `ERROR: no se pudo descifrar la llave`, en lugar de quedar en bucle.
4. Se **borran** la llave privada y la passphrase de `/run/tunnel`. Sólo queda la pública y el socket del agente.
5. Todas las (re)conexiones usan el agente: `-o IdentityAgent=… -o IdentitiesOnly=yes -i id_key.pub`.

!!! info "Variable de entorno como último recurso"
    `TUNNEL_KEY_PASSPHRASE` se acepta si no hay fichero, pero se registra un aviso: las variables de
    entorno aparecen en `kubectl describe`, `/proc/1/environ` y volcados de la spec.

## Opción A — Kubernetes Secret (por defecto)

Sin escribir YAML con valores reales:

```bash
make secrets-init                               # ./secrets/ local, validada
make known-hosts TUNNEL_REMOTE_HOST=x.x.x.x
make k8s-secret                                 # kubectl create secret … --dry-run | apply
```

Equivale a:

```bash
kubectl -n nexbridge create secret generic nexbridge-ssh \
  --from-file=id_rsa_ed25519=./secrets/id_rsa_ed25519 \
  --from-file=passphrase=./secrets/passphrase \
  --from-file=known_hosts=./secrets/known_hosts
```

El Deployment lo monta con `defaultMode: 0400` y `readOnly: true`. `k8s/secret.example.yaml` documenta la
forma, **nunca** se versiona `k8s/secret.yaml` (está en `.gitignore`).

!!! warning "Los Secrets de Kubernetes van en base64, no cifrados"
    Asegura que AKS tiene **cifrado en reposo de etcd con KMS** y que el RBAC limita `get secrets`
    en el namespace `nexbridge`. Para producción, prefiere la opción B.

## Opción B — Azure Key Vault + Secrets Store CSI (producción)

```bash
# 1. Add-on en el clúster
az aks enable-addons --addons azure-keyvault-secrets-provider -g <rg> -n <aks>

# 2. Secretos en Key Vault
az keyvault secret set --vault-name <kv> -n nexbridge-ssh-key        -f ./secrets/id_rsa_ed25519
az keyvault secret set --vault-name <kv> -n nexbridge-ssh-passphrase -f ./secrets/passphrase
az keyvault secret set --vault-name <kv> -n nexbridge-ssh-known-hosts -f ./secrets/known_hosts

# 3. Acceso con Workload Identity (rol "Key Vault Secrets User" sobre el vault)
```

Aplica `k8s/optional/keyvault-secretproviderclass.yaml` (rellenando `clientID`, `keyvaultName`,
`tenantId`) y cambia el volumen `ssh-secret` del Deployment por el CSI:

```yaml
volumes:
  - name: ssh-secret
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: nexbridge-kv
```

La ruta de montaje no cambia, así que el contenedor no necesita ninguna modificación.

## Opción C — Docker Compose (local)

`docker-compose.yml` declara tres *Docker secrets* a partir de `./secrets/` y los monta en
`/run/secrets/tunnel/`. `make secrets-init` los genera.

## Rotación

```bash
# 1. Nueva llave en el OnPrem (añadir a authorized_keys de aks-nemesis, sin quitar la antigua)
ssh-keygen -t ed25519 -f secrets/id_rsa_ed25519.new -C "aks-nemesis@aks $(date +%F)"
# 2. Actualiza ./secrets/, luego:
make k8s-secret
kubectl -n nexbridge rollout restart deploy/nexbridge
# 3. Retira la llave antigua del OnPrem cuando los pods estén Ready.
```

Con Key Vault, sube la nueva versión del secreto y reinicia el Deployment (o habilita la
rotación del add-on CSI).

## Host key

Sin `known_hosts`, el contenedor usa `StrictHostKeyChecking=accept-new` (*trust on first use*) y lo
avisa en el log. En AKS **proporciona siempre `known_hosts`**: es lo que impide que un equipo intermedio
suplante al OnPrem y reciba los prompts enviados a la IA.
