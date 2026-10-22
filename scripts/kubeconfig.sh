#!/usr/bin/env bash
# Выпускает kubeconfig участника: ServiceAccount team-user в namespace команды, токен с сроком жизни.
# Использование: kubeconfig.sh <имя>     Окружение: KUBECONFIG (admin), TOKEN_DURATION (по умолчанию 96h)
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?имя}
[[ $name == team-* ]] || name="team-$name"
dur=${TOKEN_DURATION:-96h}

server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ca=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
token=$(kubectl -n "$name" create token team-user --duration="$dur")

mkdir -p .local
out=".local/kubeconfig-$name.yaml"
umask 077
cat > "$out" <<KC
apiVersion: v1
kind: Config
clusters:
  - name: hack
    cluster:
      server: $server
      certificate-authority-data: $ca
users:
  - name: $name
    user:
      token: $token
contexts:
  - name: $name
    context:
      cluster: hack
      user: $name
      namespace: $name
current-context: $name
KC
echo "✅ $out (токен действует $dur, доступ только к namespace $name)"
