# hack-manifests: утилиты для манифестов и секретов.
# Логика лежит в scripts/, здесь только параметры и точки входа.

SHELL        := /bin/bash
.DEFAULT_GOAL := help

# ── Параметры окружения хакатона (можно переопределить: make ... BASE_DOMAIN=...) ──
REPO_URL    ?= https://github.com/LROOP2022/hack-manifests.git
REPO_BRANCH ?= main
# GHCR требует имя организации в нижнем регистре
IMAGE_ORG   ?= lroop2022
BASE_DOMAIN ?= hack.week-infra.ru
PUBKEY      ?= sealed-secrets.pub.pem
# тот же тег mc, что в platform/minio/backup-cronjob.yaml
MC_IMAGE    ?= minio/mc:RELEASE.2025-04-16T18-13-26Z

# Квота команды по умолчанию (нода apps: 4 vCPU / 6 GB на все команды)
QUOTA_REQ_CPU ?= 2
QUOTA_REQ_MEM ?= 2Gi
QUOTA_LIM_CPU ?= 4
QUOTA_LIM_MEM ?= 3Gi

export REPO_URL REPO_BRANCH IMAGE_ORG BASE_DOMAIN PUBKEY MC_IMAGE
export QUOTA_REQ_CPU QUOTA_REQ_MEM QUOTA_LIM_CPU QUOTA_LIM_MEM

.PHONY: help team scaffold seal create db kubeconfig lint status pubkey-update

help: ## Показать команды
	@echo ""
	@echo "  hack-manifests"
	@echo ""
	@echo "  Команда участников:"
	@echo "    make team NAME=a                                   namespace team-a: доступ, квота, Application"
	@echo "    make scaffold TYPE=backend PARENT=team-a RESOURCE=api [DOMAIN=...] [PORT=8080] [IMAGE_REPO=...]"
	@echo "                  TYPE: frontend | backend | bot. DOMAIN по умолчанию <RESOURCE>.<PARENT>.$(BASE_DOMAIN)"
	@echo "    make db NAME=a                                     база PostgreSQL + бакет MinIO -> .local/a.db.env"
	@echo "    make kubeconfig NAME=a [TOKEN_DURATION=96h]        kubeconfig участника (только namespace команды)"
	@echo ""
	@echo "  Секреты:"
	@echo "    make seal PARENT=platform RESOURCE=postgresql      <PARENT>/<RESOURCE>/secrets/<RESOURCE>.env -> SealedSecret"
	@echo "    make create PARENT=... RESOURCE=...                пустой .env для нового ресурса"
	@echo "    make pubkey-update                                 обновить $(PUBKEY) из кластера"
	@echo "    make status                                        sealed-secrets и найденные .env"
	@echo ""
	@echo "  Проверка:"
	@echo "    make lint                                          kustomize build всех приложений"
	@echo ""

team: ## make team NAME=a
	@test -n "$(NAME)" || (echo "❌ Укажи NAME=имя команды"; exit 1)
	@scripts/team.sh "$(NAME)"

scaffold: ## make scaffold TYPE=backend PARENT=team-a RESOURCE=api
	@test -n "$(TYPE)" -a -n "$(PARENT)" -a -n "$(RESOURCE)" || (echo "❌ Нужны TYPE, PARENT, RESOURCE (см. make help)"; exit 1)
	@IMAGE_REPO="$(IMAGE_REPO)" scripts/scaffold.sh "$(TYPE)" "$(PARENT)" "$(RESOURCE)" "$(DOMAIN)" "$(PORT)"

seal: ## make seal PARENT=... RESOURCE=...
	@test -n "$(PARENT)" -a -n "$(RESOURCE)" || (echo "❌ Нужны PARENT и RESOURCE"; exit 1)
	@scripts/seal.sh "$(PARENT)" "$(RESOURCE)"

create: ## make create PARENT=... RESOURCE=...
	@test -n "$(PARENT)" -a -n "$(RESOURCE)" || (echo "❌ Нужны PARENT и RESOURCE"; exit 1)
	@mkdir -p "$(PARENT)/$(RESOURCE)/secrets"
	@test -f "$(PARENT)/$(RESOURCE)/secrets/$(RESOURCE).env" || (touch "$(PARENT)/$(RESOURCE)/secrets/$(RESOURCE).env" && echo "📄 $(PARENT)/$(RESOURCE)/secrets/$(RESOURCE).env")

db: ## make db NAME=a
	@test -n "$(NAME)" || (echo "❌ Укажи NAME=имя команды"; exit 1)
	@scripts/db.sh "$(NAME)"

kubeconfig: ## make kubeconfig NAME=a
	@test -n "$(NAME)" || (echo "❌ Укажи NAME=имя команды"; exit 1)
	@TOKEN_DURATION="$(TOKEN_DURATION)" scripts/kubeconfig.sh "$(NAME)"

lint: ## kustomize build всех приложений
	@scripts/lint.sh

status: ## Состояние sealed-secrets и локальные .env
	@echo "── Контроллер sealed-secrets ──"
	@kubectl -n kube-system get deployment sealed-secrets-controller || true
	@echo "── SealedSecret в кластере ──"
	@kubectl get sealedsecrets -A 2>/dev/null || echo "  (нет или CRD не установлен)"
	@echo "── .env в рабочей копии (в git попадать не должны) ──"
	@find . -name "*.env" -not -path "./.git/*" | sort

pubkey-update: ## Обновить публичный ключ Sealed Secrets из кластера
	kubeseal --fetch-cert --controller-namespace kube-system --controller-name sealed-secrets-controller > "$(PUBKEY).tmp"
	@mv "$(PUBKEY).tmp" "$(PUBKEY)"
	@echo "✅ $(PUBKEY) обновлён: закоммитьте, если изменился (ключ другого кластера секреты не расшифрует)"
