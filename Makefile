SHELL       := /bin/bash
VERSION     ?= 1.0.0
IMAGE       ?= nexbridge
ACR         ?= <tu-acr>.azurecr.io
NAMESPACE   ?= nexbridge
SECRETS_DIR ?= ./secrets
KEY         ?= id_rsa_ed25519
HEALTH_PATH ?= /v1/models

.DEFAULT_GOAL := help
.PHONY: help build run ssh keys logs stop clean \
        secrets-init known-hosts test-tunnel shell lint \
        push k8s-secret k8s-apply k8s-status k8s-logs k8s-test k8s-delete \
        docs-install docs-serve docs-build release-artifacts

help: ## Lista los comandos disponibles
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --- Local (Docker) ----------------------------------------------------------
build: ## Construye la imagen
	VERSION=$(VERSION) docker compose build

run: ## Arranca el contenedor (túnel + sandbox) en segundo plano
	VERSION=$(VERSION) docker compose up -d

ssh: ## Conecta al sandbox sshd (password: tester123)
	ssh tester@localhost -p 2222

keys: ## Genera par de llaves del sandbox en ./keys/
	./generate-keys.sh

logs: ## Sigue los logs del contenedor
	docker compose logs -f

stop: ## Para el contenedor
	docker compose down

clean: ## Para y borra volúmenes
	docker compose down -v

shell: ## Shell dentro del contenedor
	docker compose exec nexbridge bash

secrets-init: ## Prepara ./secrets/ (llave, passphrase, known_hosts) de forma interactiva
	@./scripts/secrets-init.sh "$(SECRETS_DIR)" "$(KEY)"

known-hosts: ## Captura la host key del OnPrem (TUNNEL_REMOTE_HOST=...)
	@test -n "$(TUNNEL_REMOTE_HOST)" || { echo "Uso: make known-hosts TUNNEL_REMOTE_HOST=x.x.x.x"; exit 1; }
	ssh-keyscan -p 443 -t ed25519,rsa,ecdsa $(TUNNEL_REMOTE_HOST) > $(SECRETS_DIR)/known_hosts
	@echo "→ verifica la huella con el equipo OnPrem:"; ssh-keygen -lf $(SECRETS_DIR)/known_hosts

test-tunnel: ## Comprueba el servicio OnPrem a través del túnel local
	curl -fsS http://localhost:3000$(HEALTH_PATH) | head -c 600; echo

lint: ## shellcheck + validación de manifiestos
	shellcheck entrypoint.sh scripts/*.sh generate-keys.sh
	kubectl kustomize k8s/ >/dev/null && echo "kustomize OK"

# --- AKS ---------------------------------------------------------------------
push: ## Construye linux/amd64 y publica en ACR
	az acr login --name $(firstword $(subst ., ,$(ACR)))
	docker buildx build --platform linux/amd64 --build-arg VERSION=$(VERSION) \
	  -t $(ACR)/$(IMAGE):$(VERSION) -t $(ACR)/$(IMAGE):latest --push .

k8s-secret: ## Crea/actualiza el Secret desde ./secrets/ (sin escribir YAML)
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(NAMESPACE) create secret generic nexbridge-ssh \
	  --from-file=$(KEY)=$(SECRETS_DIR)/$(KEY) \
	  --from-file=passphrase=$(SECRETS_DIR)/passphrase \
	  --from-file=known_hosts=$(SECRETS_DIR)/known_hosts \
	  --dry-run=client -o yaml | kubectl apply -f -

k8s-apply: ## Despliega con kustomize
	kubectl apply -k k8s/

k8s-status: ## Estado del despliegue
	kubectl -n $(NAMESPACE) get deploy,pods,svc -l app.kubernetes.io/name=nexbridge

k8s-logs: ## Logs del túnel en AKS
	kubectl -n $(NAMESPACE) logs -l app.kubernetes.io/name=nexbridge -f --tail=200

k8s-test: ## Prueba el servicio desde un pod efímero dentro del clúster
	kubectl -n $(NAMESPACE) run tunnel-probe --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- \
	  curl -fsS -m 10 http://nexbridge.$(NAMESPACE).svc.cluster.local:3000$(HEALTH_PATH)

k8s-delete: ## Elimina los recursos (no borra el Secret)
	kubectl delete -k k8s/

# --- Release -----------------------------------------------------------------
DIST      ?= dist
PLATFORMS ?= linux/amd64 linux/arm64

release-artifacts: ## Imagen por plataforma (.tar.gz) + SHA256SUMS en dist/
	@mkdir -p $(DIST)
	@for p in $(PLATFORMS); do \
	  arch=$${p#*/}; out=$(DIST)/$(IMAGE)-$(VERSION)-linux-$$arch.tar.gz; \
	  echo "→ $$p"; \
	  docker buildx build --platform $$p --build-arg VERSION=$(VERSION) \
	    -t $(IMAGE):$(VERSION) --output type=docker,dest=- . | gzip -9 > $$out; \
	done
	@cd $(DIST) && shasum -a 256 $(IMAGE)-$(VERSION)-*.tar.gz > SHA256SUMS && cat SHA256SUMS

# --- Documentación -----------------------------------------------------------
docs-install: ## Instala mkdocs-material
	$(MAKE) -C docs install

docs-serve: ## Sirve la documentación en http://127.0.0.1:8000
	$(MAKE) -C docs serve

docs-build: ## Genera el sitio estático en docs/site/
	$(MAKE) -C docs build
