# Primeros pasos

## Requisitos

- Docker 24+ con Compose v2
- La llave privada autorizada para `aks-nemesis` en el OnPrem (`id_rsa_ed25519`) y su **passphrase**
- Para AKS: `az`, `kubectl` y acceso al ACR

## 1. Preparar secretos locales

```bash
make secrets-init                       # copia la llave y pide la passphrase sin eco
make known-hosts TUNNEL_REMOTE_HOST=x.x.x.x   # fija la host key del OnPrem
```

`secrets-init` deja en `./secrets/` (ignorado por git, permisos `0600`):

```
secrets/
├── id_rsa_ed25519   # llave privada cifrada
├── passphrase       # passphrase, sin salto de línea
└── known_hosts      # host key del OnPrem (recomendado)
```

y **valida** que la passphrase descifra la llave antes de terminar.

!!! warning "Verifica la huella"
    `make known-hosts` imprime la huella SHA256 capturada. Compárala con la del OnPrem
    (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`) antes de confiar en ella.

## 2. Configurar el destino

```bash
cp .env.example .env
# edita TUNNEL_REMOTE_HOST=<ip-onprem>
```

## 3. Levantar

```bash
make build
make run
make logs
```

```text
[entrypoint] === tunnel-connect 1.0.0 ===
[entrypoint]   túnel:   true  → aks-nemesis@x.x.x.x:443
[tunnel] llave cargada en ssh-agent (SHA256:…)
[tunnel] abriendo túnel (intento 1)
Authenticated to x.x.x.x ([x.x.x.x]:443) using "publickey".
```

## 4. Probar

```bash
make test-tunnel            # curl http://localhost:3000/v1/models
```

## Siguiente paso

[Despliegue en AKS →](guides/despliegue-aks.md)
