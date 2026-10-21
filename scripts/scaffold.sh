#!/usr/bin/env bash
# Создаёт манифесты компонента и (если нужно) Application проекта.
# Использование: scaffold.sh <frontend|backend|bot> <PARENT> <RESOURCE> [DOMAIN] [PORT]
# Окружение: IMAGE_ORG, IMAGE_REPO (по умолчанию = RESOURCE), BASE_DOMAIN, REPO_URL, REPO_BRANCH
set -euo pipefail
cd "$(dirname "$0")/.."
type=${1:?TYPE}; parent=${2:?PARENT}; res=${3:?RESOURCE}; domain=${4:-}; port=${5:-}

case $type in frontend|backend|bot) ;; *) echo "❌ TYPE: frontend | backend | bot" >&2; exit 1;; esac
[[ $parent =~ ^[a-z][a-z0-9-]*$ && $res =~ ^[a-z][a-z0-9-]*$ ]] || { echo "❌ PARENT и RESOURCE: a-z, 0-9, дефис" >&2; exit 1; }

if [[ -z $port ]]; then [[ $type == frontend ]] && port=3000 || port=8080; fi
[[ -n $domain ]] || domain="$res.$parent.${BASE_DOMAIN:?}"
image="ghcr.io/${IMAGE_ORG:?}/${IMAGE_REPO:-$res}"
dir="$parent/$res"
mkdir -p "$dir"

if [[ $type == bot ]]; then echo "── scaffold: bot · $dir ──"; else echo "── scaffold: $type · $dir · https://$domain ──"; fi
for tpl in templates/$type/*.tpl; do
  name=$(basename "$tpl" .tpl)
  if [[ -e $dir/$name ]]; then echo "⚠️  $dir/$name уже есть, пропускаю"; continue; fi
  scripts/render.sh "$tpl" NAME="$res" IMAGE="$image" PORT="$port" DOMAIN="$domain" > "$dir/$name"
  echo "📄 $dir/$name"
done

if [[ $type != frontend ]]; then
  mkdir -p "$dir/secrets"
  if [[ ! -e $dir/secrets/$res.env ]]; then
    printf '# Секреты %s/%s. Пример: SPRING_DATASOURCE_PASSWORD=xxx\n# Значения БД и S3 выдаёт make db (.local/<имя>.db.env)\n' "$parent" "$res" > "$dir/secrets/$res.env"
    echo "📄 $dir/secrets/$res.env (не коммитится)"
  fi
fi

if [[ ! -e applications/$parent.yml ]]; then
  scripts/render.sh templates/application.yml.tpl PARENT="$parent" REPO_URL="${REPO_URL:?}" REPO_BRANCH="${REPO_BRANCH:?}" > "applications/$parent.yml"
  echo "📄 applications/$parent.yml"
fi
scripts/add-resource.sh "$parent" "$res"

echo
echo "Дальше:"
if [[ $type != frontend ]]; then
  echo "  1. заполнить $dir/secrets/$res.env"
  echo "  2. make seal PARENT=$parent RESOURCE=$res"
  echo "  3. git add . && git commit && git push"
else
  echo "  git add . && git commit && git push"
fi
echo "  Тег образа выставит workflow update-kustomize после первого push в репозиторий сервиса."
