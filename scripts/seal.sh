#!/usr/bin/env bash
# Запечатывает <PARENT>/<RESOURCE>/secrets/<RESOURCE>.env в SealedSecret `<RESOURCE>-secrets`
# и подключает его в kustomization.yaml компонента.
# Использование: seal.sh <PARENT> <RESOURCE>   Окружение: PUBKEY
set -euo pipefail
cd "$(dirname "$0")/.."
parent=${1:?PARENT}; res=${2:?RESOURCE}; pub=${PUBKEY:?}
env_file="$parent/$res/secrets/$res.env"
out="$parent/$res/secrets/$res-sealed.yaml"
[[ -f $env_file ]] || { echo "❌ нет $env_file (образец: $env_file.example)" >&2; exit 1; }
[[ -f $pub ]] || { echo "❌ нет $pub. Скопируйте artifacts/sealed-secrets.pub.pem из hack-node-setup или make pubkey-update" >&2; exit 1; }
if grep -qE 'CHANGE-ME|СГЕНЕРИРУЙ' "$env_file"; then echo "❌ в $env_file остались значения CHANGE-ME" >&2; exit 1; fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
kubectl create secret generic "$res-secrets" --from-env-file="$env_file" \
  --namespace "$parent" --dry-run=client -o yaml | kubeseal --cert "$pub" --format yaml > "$tmp"
[[ -s $tmp ]] || { echo "❌ kubeseal вернул пустой результат" >&2; exit 1; }
mv "$tmp" "$out"
trap - EXIT
scripts/add-resource.sh "$parent/$res" "secrets/$res-sealed.yaml"
echo "✅ $out обновлён. Коммитьте sealed-файл, а $env_file никогда (в .gitignore)."
