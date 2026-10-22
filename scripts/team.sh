#!/usr/bin/env bash
# Создаёт namespace-проект команды: ограниченный доступ (SA + Role), квоты и Application.
# Использование: team.sh <имя>   (team- добавится сам)
# Окружение: REPO_URL, REPO_BRANCH, QUOTA_REQ_CPU, QUOTA_REQ_MEM, QUOTA_LIM_CPU, QUOTA_LIM_MEM
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?имя команды}
[[ $name == team-* ]] || name="team-$name"
[[ $name =~ ^team-[a-z][a-z0-9-]*$ ]] || { echo "❌ имя: a-z, 0-9, дефис" >&2; exit 1; }

mkdir -p "$name/access"
for tpl in templates/team/access/*.tpl; do
  f="$name/access/$(basename "$tpl" .tpl)"
  [[ -e $f ]] && { echo "⚠️  $f уже есть, пропускаю"; continue; }
  scripts/render.sh "$tpl" REQ_CPU="${QUOTA_REQ_CPU:?}" REQ_MEM="${QUOTA_REQ_MEM:?}" LIM_CPU="${QUOTA_LIM_CPU:?}" LIM_MEM="${QUOTA_LIM_MEM:?}" > "$f"
  echo "📄 $f"
done
scripts/add-resource.sh "$name" access
if [[ ! -e applications/$name.yml ]]; then
  scripts/render.sh templates/application.yml.tpl PARENT="$name" REPO_URL="${REPO_URL:?}" REPO_BRANCH="${REPO_BRANCH:?}" > "applications/$name.yml"
  echo "📄 applications/$name.yml"
fi
echo
echo "Дальше: git push, затем  make kubeconfig NAME=$name  (kubeconfig участника)"
echo "        make db NAME=${name#team-}                    (база, пользователь, бакет)"
