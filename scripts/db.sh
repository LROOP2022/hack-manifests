#!/usr/bin/env bash
# Выдаёт команде базу PostgreSQL (отдельный пользователь, чужие базы закрыты) и бакет MinIO
# (отдельный пользователь с доступом только к своему бакету). Нужен admin kubeconfig.
# Использование: db.sh <имя>      Результат: .local/<имя>.db.env (права 600)
# Повторный запуск для существующего имени отказывается работать: пароли не перевыпускаются молча.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?имя}; ns=platform
[[ $name =~ ^[a-z][a-z0-9-]{2,30}$ ]] || { echo "❌ имя: 3–31 символ, a-z, 0-9, дефис, начинается с буквы" >&2; exit 1; }
mc_image=${MC_IMAGE:?}
dbname=${name//-/_}

psql_run() {
  kubectl -n "$ns" exec -i postgresql-0 -c postgresql -- \
    sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 -tA'
}
secret_val() { kubectl -n "$ns" get secret "$1" -o "jsonpath={.data.$2}" | base64 -d; }

echo "→ проверяю, что $name ещё не выдавался"
if [[ $(echo "SELECT 1 FROM pg_roles WHERE rolname='$dbname'" | psql_run) == 1 ]]; then
  echo "❌ пользователь $dbname уже есть в PostgreSQL. Данные не перевыпускаются автоматически." >&2; exit 1
fi

db_pass=$(openssl rand -hex 16)
s3_secret=$(openssl rand -hex 16)
minio_user=$(secret_val minio-secrets MINIO_ROOT_USER)
minio_pass=$(secret_val minio-secrets MINIO_ROOT_PASSWORD)
redis_pass=$(secret_val redis-secrets REDIS_PASSWORD)

echo "→ MinIO: бакет и пользователь"
mc_script='
set -e
export MC_CONFIG_DIR=/tmp/mc
mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
if mc admin user info local "$S3_ACCESS" >/dev/null 2>&1; then echo EXISTS; exit 0; fi
mc mb --ignore-existing "local/$BUCKET" >/dev/null
cat > /tmp/policy.json <<POLICY
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:*"],"Resource":["arn:aws:s3:::$BUCKET","arn:aws:s3:::$BUCKET/*"]}]}
POLICY
mc admin policy create local "$BUCKET-rw" /tmp/policy.json >/dev/null
mc admin user add local "$S3_ACCESS" "$S3_SECRET" >/dev/null
mc admin policy attach local "$BUCKET-rw" --user "$S3_ACCESS" >/dev/null
echo OK'
mc_out=$(kubectl -n "$ns" run "mc-db-$RANDOM" --rm -i --quiet --restart=Never --image="$mc_image" \
  --env "MINIO_ROOT_USER=$minio_user" --env "MINIO_ROOT_PASSWORD=$minio_pass" \
  --env "BUCKET=$name" --env "S3_ACCESS=$name" --env "S3_SECRET=$s3_secret" \
  --command -- sh -c "$mc_script")
case $mc_out in
  *EXISTS*) echo "❌ пользователь MinIO $name уже существует" >&2; exit 1;;
  *OK*) ;;
  *) echo "❌ неожиданный ответ mc: $mc_out" >&2; exit 1;;
esac

echo "→ PostgreSQL: база и пользователь"
psql_run <<SQL
CREATE ROLE "$dbname" LOGIN PASSWORD '$db_pass';
CREATE DATABASE "$dbname" OWNER "$dbname";
REVOKE ALL ON DATABASE "$dbname" FROM PUBLIC;
SQL

mkdir -p .local
out=".local/$name.db.env"
umask 077
cat > "$out" <<ENV
# Выдано $(date -u +%FT%TZ) для $name. Только из кластера: *.platform.svc
DB_HOST=postgresql.platform.svc
DB_PORT=5432
DB_NAME=$dbname
DB_USER=$dbname
DB_PASSWORD=$db_pass
SPRING_DATASOURCE_URL=jdbc:postgresql://postgresql.platform.svc:5432/$dbname
SPRING_DATASOURCE_USERNAME=$dbname
SPRING_DATASOURCE_PASSWORD=$db_pass
REDIS_HOST=redis.platform.svc
REDIS_PORT=6379
REDIS_PASSWORD=$redis_pass
SPRING_DATA_REDIS_HOST=redis.platform.svc
SPRING_DATA_REDIS_PASSWORD=$redis_pass
S3_ENDPOINT=http://minio.platform.svc:9000
S3_BUCKET=$name
S3_ACCESS_KEY=$name
S3_SECRET_KEY=$s3_secret
ENV
echo "✅ $out"
echo "   Нужные строки скопируйте в <PARENT>/<RESOURCE>/secrets/<RESOURCE>.env и выполните make seal."
echo "   Redis общий для всех команд: просите использовать префикс ключей \"$name:\"."
