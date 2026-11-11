# NexBridge

![NexBridge](assets/banner.svg)

**NexBridge** publica dentro de un clúster **AKS** servicios que viven en un **servidor OnPrem**, a
través de un túnel SSH saliente, cifrado y autenticado por llave. El servicio OnPrem sigue escuchando
sólo en `127.0.0.1` y se consume desde el clúster como un `Service` de Kubernetes.

Caso de uso actual: la **IA local compatible con la API de OpenAI** del OnPrem, consumida desde AKS por
[NexIA](guides/consumir-ia.md#nexia) y otras aplicaciones en:

```text
http://nexbridge.nexbridge.svc.cluster.local:3000/v1
```

## Cómo funciona, en una línea

Al arrancar, el pod ejecuta y mantiene vivo:

```bash
ssh -vvv -NT \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -p 443 \
  -i id_rsa_ed25519 \
  -L 0.0.0.0:3000:127.0.0.1:3000 \
  aks-nemesis@<onprem>
```

![Flujo](assets/flow.svg)

## Por qué así

| Necesidad | Cómo se resuelve |
|---|---|
| El OnPrem sólo acepta conexiones entrantes por 443 | El pod inicia la sesión **saliente** a `:443` |
| La IA local no debe exponerse a la red | Escucha en `127.0.0.1`; sólo se alcanza por el túnel autenticado |
| La llave SSH está protegida con passphrase | Llave y passphrase en **Secret** o **Azure Key Vault**, descifrada en `ssh-agent`, nunca en disco |
| Cortes de red y reinicios del OnPrem | Reconexión con backoff exponencial y probes de Kubernetes |
| Los consumidores no deben saber de SSH | Un endpoint HTTP compatible con OpenAI dentro del clúster |

## Empieza aquí

<div class="grid cards" markdown>

-   **Primeros pasos**

    ---

    Levanta el túnel en local con Docker Compose en cinco comandos.

    [→ Primeros pasos](getting-started.md)

-   **Instalación desde release**

    ---

    Descarga la imagen publicada, verifica su suma y súbela a ACR.

    [→ Instalación](guides/instalacion.md)

-   **Despliegue en AKS**

    ---

    Secret, kustomize, probes, NetworkPolicy y alta disponibilidad.

    [→ Despliegue](guides/despliegue-aks.md)

-   **Arquitectura**

    ---

    Secuencia completa y diagrama animado del arranque, las peticiones y la reconexión.

    [→ Flujo OnPrem → AKS](architecture/flujo.md)

-   **Secretos**

    ---

    Cómo se custodian la llave y la passphrase, y cómo rotarlas.

    [→ Secretos y passphrase](guides/secretos.md)

-   **Seguridad**

    ---

    Límites de confianza, amenazas, mitigaciones y riesgos aceptados.

    [→ Modelo de seguridad](architecture/seguridad.md)

</div>

## Componentes

| Componente | Función |
|---|---|
| `entrypoint.sh` | Prepara las credenciales en un tmpfs y cede privilegios al usuario `tunnel` |
| `scripts/tunnel.sh` | Carga la llave en `ssh-agent` y mantiene el túnel con reconexión |
| `scripts/askpass.sh` | Entrega la passphrase a `ssh-add` una única vez |
| `scripts/healthcheck.sh` | Comprueba los listeners y, en modo `--deep`, el servicio remoto por HTTP |
| `k8s/` | Manifiestos kustomize para AKS |
