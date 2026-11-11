# Despliegue en AKS

## Recursos

```
k8s/
├── kustomization.yaml       # namespace, imagen y etiquetas comunes
├── namespace.yaml           # nexbridge (Pod Security: baseline)
├── serviceaccount.yaml      # sin token montado
├── configmap.yaml           # destino, forwards, verbosidad, health path
├── deployment.yaml          # 1 réplica, probes, rootfs ro, emptyDir en memoria
├── service.yaml             # ClusterIP :3000
├── pdb.yaml
├── secret.example.yaml      # forma del Secret (NO aplicar con valores reales)
└── optional/
    ├── networkpolicy.yaml               # ingress sólo desde consumidores, egress sólo a OnPrem:443
    └── keyvault-secretproviderclass.yaml
```

## Pasos

```bash
# 1. Imagen
make push ACR=<tu-acr>.azurecr.io VERSION=1.0.1

# 2. Configuración: edita k8s/configmap.yaml (TUNNEL_REMOTE_HOST) y
#    k8s/kustomization.yaml (images.newName = <tu-acr>.azurecr.io/nexbridge)

# 3. Secreto (ver guía de secretos)
make k8s-secret

# 4. Desplegar
make k8s-apply
make k8s-status
make k8s-logs

# 5. Probar desde dentro del clúster
make k8s-test     # curl http://nexbridge.nexbridge.svc.cluster.local:3000/v1/models
```

Si AKS no tiene `AcrPull` sobre el registro: `az aks update -g <rg> -n <aks> --attach-acr <acr>`.

## Probes

| Probe | Comando | Propósito |
|---|---|---|
| `startupProbe` | `healthcheck.sh` | Hasta 2 min para el primer túnel |
| `readinessProbe` | `healthcheck.sh --deep` | Listener abierto **y** `GET $TUNNEL_HEALTH_PATH` responde por el túnel |
| `livenessProbe` | `healthcheck.sh` | 2 min sin listener → reinicio del contenedor |

La readiness profunda hace que un pod cuyo túnel está arriba pero cuya IA local no responde salga del
Service. Vacía `TUNNEL_HEALTH_PATH` si el servicio remoto no tiene un endpoint barato de comprobar.

## Seguridad del pod

- `ssh` corre como `tunnel` (uid 10001); sólo el entrypoint es root, para preparar credenciales y bajar privilegios con `su-exec`.
- `readOnlyRootFilesystem: true`; lo único escribible es `/run/tunnel` (`emptyDir`, `medium: Memory`, 1 Mi).
- Capabilities: `drop: ALL` + las mínimas para `chown`/`su-exec` (`CHOWN`, `FOWNER`, `DAC_OVERRIDE`, `SETUID`, `SETGID`).
- `automountServiceAccountToken: false`: el pod no habla con la API de Kubernetes.
- `SSHD_ENABLED=false`: el sandbox con passwords por defecto **no** se activa en AKS.

## NetworkPolicy (recomendado)

```bash
# Ajusta el CIDR del OnPrem y etiqueta los namespaces que pueden consumir el túnel
kubectl label ns nexia nexbridge/consumer=true
kubectl apply -f k8s/optional/networkpolicy.yaml
```

Requiere AKS con network policy (Azure NPM, Calico o Cilium).

## Alta disponibilidad

Por defecto `replicas: 1`. Para HA sube a 2: cada pod abre su propia sesión SSH y el Service reparte.
Comprueba antes que el OnPrem lo admite (`MaxSessions`, `MaxStartups`, límites por usuario) y que la IA
local soporta la concurrencia sumada.

```bash
kubectl -n nexbridge scale deploy/nexbridge --replicas=2
```

## Actualizar

```bash
make push VERSION=1.0.1
# kustomization.yaml → newTag: "1.0.1"
make k8s-apply
kubectl -n nexbridge rollout status deploy/nexbridge
```

`maxUnavailable: 0` + `maxSurge: 1`: el pod nuevo abre su túnel y pasa readiness antes de retirar el viejo.
