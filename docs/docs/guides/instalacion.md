# Instalación desde una release

Cada versión de NexBridge publica en GitHub Releases la **imagen ya construida** como artefacto, para
desplegar sin compilar y sin depender de un registro externo.

## Artefactos

| Fichero | Contenido |
|---|---|
| `nexbridge-<versión>-linux-amd64.tar.gz` | Imagen para AKS y servidores x86_64 |
| `nexbridge-<versión>-linux-arm64.tar.gz` | Imagen para Apple Silicon y nodos ARM |
| `SHA256SUMS` | Sumas SHA-256 de los artefactos |

## 1. Descargar y verificar

```bash
VERSION=1.0.1
gh release download v$VERSION --repo JGandiaC/NexBridge \
  --pattern "nexbridge-$VERSION-linux-amd64.tar.gz" --pattern SHA256SUMS

shasum -a 256 --ignore-missing -c SHA256SUMS      # macOS
# sha256sum --ignore-missing -c SHA256SUMS        # Linux
```

!!! warning "No cargues una imagen sin verificar"
    Si la suma no coincide, descarta el fichero. La imagen tiene acceso a la llave SSH del OnPrem.

## 2. Cargar en Docker

```bash
docker load -i nexbridge-$VERSION-linux-amd64.tar.gz
docker image ls nexbridge
# nexbridge   1.0.1   …
```

## 3a. Ejecutar en local

```bash
make secrets-init
make known-hosts TUNNEL_REMOTE_HOST=<ip-onprem>
docker compose up -d --no-build
```

## 3b. Publicar en ACR y desplegar en AKS

```bash
ACR=<registro>.azurecr.io
az acr login --name ${ACR%%.*}
docker tag nexbridge:$VERSION $ACR/nexbridge:$VERSION
docker push $ACR/nexbridge:$VERSION
```

Después, sigue [Despliegue en AKS](despliegue-aks.md) desde el paso del Secret, con `newTag: "$VERSION"`
en `k8s/kustomization.yaml`.

## Construir desde el código

Alternativa a la imagen publicada:

```bash
git clone git@github.com:JGandiaC/NexBridge.git && cd NexBridge
git checkout v1.0.1
make build                                   # local
make push ACR=<registro>.azurecr.io VERSION=1.0.1   # linux/amd64 directo a ACR
```
