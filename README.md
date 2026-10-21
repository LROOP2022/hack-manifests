# hack-manifests

GitOps-репозиторий кластера хакатона. Ansible (`hack-node-setup`) ставит k3s, ingress-nginx, cert-manager, Sealed Secrets и Argo CD; всё остальное Argo CD берёт отсюда. Домен стендов: `*.hack.week-infra.ru`.

## Структура

```
root-application.yml        App of Apps (применяет Ansible: --tags root), prune выключен
applications/               по одному Application на проект
  platform.yml              platform/  → namespace platform (prune: false, без finalizer)
  monitoring.yml            Helm kube-prometheus-stack (версия закреплена)
  monitoring-config.yml     monitoring/ → Ingress Grafana, ServiceMonitor'ы, секрет Grafana
platform/                   postgresql · redis · minio · mlflow (все на node-2, role=data)
images/minio/               Dockerfile образа MinIO + mc (сборка: .github/workflows/build-minio.yml)
monitoring/                 grafana/ · ingress-nginx · spring-servicemonitor
templates/  scripts/        шаблоны и логика для make team / scaffold / seal / db / kubeconfig
Makefile                    точки входа (make help)
```

## Первый запуск (порядок важен)

1. **DNS:** `*.hack.week-infra.ru` A → `85.8.201.134` (только DNS, без проксирования).
2. **Ключ Sealed Secrets этого кластера:** `cp ../hack-node-setup/artifacts/sealed-secrets.pub.pem .`
3. **Секреты платформы.** Для каждого: `cp .../secrets/X.env.example .../secrets/X.env`, заполнить, запечатать.
   ```sh
   make seal PARENT=platform   RESOURCE=postgresql
   make seal PARENT=platform   RESOURCE=redis
   make seal PARENT=platform   RESOURCE=minio
   make seal PARENT=monitoring RESOURCE=grafana
   ```
   `make seal` сам дописывает `secrets/<имя>-sealed.yaml` в `kustomization.yaml`. Без секрета поды просто ждут (`CreateContainerConfigError`), Argo CD при этом не ломается.
4. `git push`, затем `ansible-playbook playbooks/site.yml --ask-vault-pass --tags root` (в `hack-node-setup`).
5. Когда Postgres и MinIO запущены (`kubectl -n platform get pods`): **MLflow**
   ```sh
   make db NAME=mlflow                   # база, пользователь, бакет -> .local/mlflow.db.env
   cp platform/mlflow/secrets/mlflow.env.example platform/mlflow/secrets/mlflow.env   # подставить значения
   make seal PARENT=platform RESOURCE=mlflow && git push
   ```
6. `make lint` перед каждым push ловит ошибки сборки kustomize.

## Новая команда

```sh
make team NAME=a                                   # namespace team-a, права, квота, Application
make db NAME=a                                     # база + бакет -> .local/a.db.env
make scaffold TYPE=backend PARENT=team-a RESOURCE=api   # домен api.team-a.hack.week-infra.ru
make seal PARENT=team-a RESOURCE=api               # после заполнения team-a/api/secrets/api.env
make kubeconfig NAME=a                             # .local/kubeconfig-team-a.yaml, токен на 96 часов
git add . && git commit && git push
```

`scaffold` кладёт в `kustomization.yaml` образ первым (`images[0]`, его меняет workflow `update-kustomize`), тег-заглушка `sha-0000000`, до первого push сервиса под в `ImagePullBackOff`. Spring: пробы `/actuator/health/{liveness,readiness}`, метрики собираются с `/actuator/prometheus` по метке Service `metrics: actuator`.

## Что проверить до применения

Контейнерные реестры недоступны из среды, где писались манифесты, поэтому эти теги **не проверены**:

| Образ | Файл |
|---|---|
| `postgres:17.6-alpine` | platform/postgresql |
| `redis:7.4.5-alpine` | platform/redis |
| `cgr.dev/chainguard/minio:latest` (сервер, незакреплён: на бесплатном плане есть только latest) | platform/minio |
| `ghcr.io/lroop2022/minio:RELEASE.2025-10-15T17-29-55Z` (только `mc`, собирается из `images/minio`, пакет Public) | platform/minio (backup), Makefile |
| `ghcr.io/mlflow/mlflow:v3.17.2` | platform/mlflow |
| `busybox:1.36` | как в проде |

Проверено: чарт `kube-prometheus-stack 92.11.0` существует; `mlflow 3.17.2`, `psycopg2-binary 2.9.13`, `boto3 1.43.116` существуют; флаги `mlflow server` (`--serve-artifacts`, `--artifacts-destination`, `--allowed-hosts`) есть; все `kustomize build` проходят, схемы Kubernetes валидны.

## Допущения и риски

- **MLflow**: образ может не содержать драйвер PostgreSQL и `boto3`, поэтому их ставит initContainer (нужен выход в интернет с node-2). `--allowed-hosts` заменяет значения по умолчанию, поэтому в списке есть `10.42.*` (CIDR подов k3s по умолчанию) и пробы сделаны TCP.
- **ingress-nginx метрики**: Service указывает на порт 10254 числом; ингресс-контроллер отдаёт метрики по умолчанию, патчить его Deployment не нужно (в проде этот патч, скорее всего, ничего не делал).
- **MinIO**: консоль выставлена наружу (`minio.hack.week-infra.ru`), S3 API только внутри кластера. Официальные образы `minio/*` удалены (Docker Hub, quay.io), community-версия заархивирована. Сервер берём из `cgr.dev/chainguard/minio:latest` (под uid 65532, `fsGroup` задан в StatefulSet). Тег `latest` нарушает `conventions.md`: записать как техдолг; после первого успешного запуска закрепить образ по digest (`kubectl -n platform get pod minio-0 -o jsonpath='{.status.containerStatuses[0].imageID}'`). В консоли нет админ-разделов: пользователи и политики через `mc` (`make db`).
- **Образ `mc`** (`make db`, бэкап) нужен с shell, поэтому собирается из `images/minio` (Actions → *Build MinIO image*, затем Packages → `minio` → Change visibility → **Public**).
- **Диск**: `local-path` не ограничивает размер PVC. Сумма запросов на node-2 около 43 ГБ при 70 ГБ диска; следите за `df -h`.
- **Бэкапы** каждые 6 часов лежат на той же ноде, что и данные. Конец каждого дня: выгрузить `/var/lib/rancher/k3s/storage/*backup*` с node-2.
- **Redis** общий, без изоляции между командами (префикс ключей по договорённости).
- **Квоты** команд по умолчанию 2 CPU / 2 Gi по requests: подберите под число команд (`QUOTA_REQ_MEM=1Gi make team NAME=a`).
