#!/usr/bin/env bash
# kustomize build для всех корневых каталогов приложений: ловит ошибки до push.
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v kustomize >/dev/null; then build=(kustomize build); else build=(kubectl kustomize); fi
rc=0
for d in $(grep -h 'path:' applications/*.yml | awk '{print $2}' | sort -u); do
  [[ -f $d/kustomization.yaml ]] || { echo "ℹ️  $d: нет kustomization.yaml (не kustomize), пропуск"; continue; }
  if "${build[@]}" "$d" >/dev/null; then echo "✅ $d"; else echo "❌ $d"; rc=1; fi
done
exit $rc
