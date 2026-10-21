#!/usr/bin/env bash
# Добавляет запись в список resources: kustomization.yaml (создаёт файл, если его нет).
# Использование: add-resource.sh <каталог> <запись>
# Условие: `resources:` должен быть последним ключом файла, запись дописывается в конец.
set -euo pipefail
dir=${1:?каталог}; entry=${2:?запись}
k="$dir/kustomization.yaml"
mkdir -p "$dir"
if [[ ! -f $k ]]; then
  printf 'apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources:\n' > "$k"
fi
if grep -qxE "[[:space:]]*-[[:space:]]+${entry}[[:space:]]*" "$k"; then
  exit 0
fi
last=$(grep -vE '^[[:space:]]*(#|$)' "$k" | tail -n1)
if ! [[ $last =~ ^[[:space:]]+-[[:space:]] || $last == "resources:" ]]; then
  echo "⚠️  $k: resources: не последний ключ, добавьте вручную: - $entry" >&2
  exit 1
fi
printf '  - %s\n' "$entry" >> "$k"
echo "➕ $entry добавлен в $k"
