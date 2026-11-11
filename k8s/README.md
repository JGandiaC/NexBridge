# k8s — NexBridge en AKS

```bash
make push ACR=<tu-acr>.azurecr.io     # imagen linux/amd64
# editar configmap.yaml (TUNNEL_REMOTE_HOST) y kustomization.yaml (images.newName)
make k8s-secret                        # Secret desde ./secrets/ (llave, passphrase, known_hosts)
make k8s-apply
make k8s-test
```

El Secret `nexbridge-ssh` **no** forma parte de kustomize: se crea con `make k8s-secret` o se
sirve desde Azure Key Vault (`optional/keyvault-secretproviderclass.yaml`).

Guía completa: `docs/docs/guides/despliegue-aks.md` y `docs/docs/guides/secretos.md`.
