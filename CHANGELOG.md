# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/).

## [1.0.0] — 2026-11-11

Primera versión estable: tunnel-connect pasa de sandbox SSH a puente OnPrem → AKS listo para producción.

### Añadido
- **Túnel OnPrem → AKS al arrancar**: el contenedor ejecuta `ssh -NT -L 0.0.0.0:3000:127.0.0.1:3000 aks-nemesis@<onprem> -p 443`
  con `ExitOnForwardFailure`, `ServerAliveInterval=30`, `ServerAliveCountMax=3` y `-vvv` configurable.
- Reconexión automática con backoff exponencial (2 → 60 s) y apagado limpio con `tini`.
- **Passphrase como secreto**: llave + passphrase + `known_hosts` montados como ficheros (Kubernetes Secret,
  Docker secrets o Azure Key Vault CSI); descifrado vía `SSH_ASKPASS` de un solo uso a `ssh-agent`; llave y
  passphrase borradas del disco tras cargarse.
- `ssh` como usuario sin privilegios `tunnel` (uid 10001) vía `su-exec`.
- `healthcheck.sh` (listener + `--deep` HTTP) usado por Docker `HEALTHCHECK` y probes de Kubernetes.
- Manifiestos `k8s/` con kustomize: Namespace, ServiceAccount, ConfigMap, Deployment, Service, PDB;
  opcionales NetworkPolicy y SecretProviderClass (Key Vault).
- `make secrets-init`, `known-hosts`, `k8s-secret`, `k8s-apply`, `k8s-test`, `push`, `lint`, `docs-*`.
- Documentación mkdocs-material con diagrama animado del flujo OnPrem → AKS.

### Cambiado
- El sandbox sshd pasa a ser opcional (`SSHD_ENABLED`); activo en `docker-compose.yml`, desactivado en la imagen y en AKS.
- Passwords del sandbox configurables en runtime (`SANDBOX_TESTER_PASSWORD`, `SANDBOX_ROOT_PASSWORD`).
- `.gitignore` cubre `secrets/`, `.env`, `k8s/secret.yaml` y artefactos `*.tar`.

## [0.1.0]

### Añadido
- Sandbox de servidor SSH (Alpine) para pruebas de conectividad, túneles y autenticación con llaves.

[1.0.0]: https://github.com/JGandiaC/tunnel-connect/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/JGandiaC/tunnel-connect/releases/tag/v0.1.0
