#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
source dev-frontend.env
set +a

compose=(docker compose -p laravel-e2e -f compose.yml -f compose.e2e.yml -f compose.rpc.yml)
dotenv_backup=$(mktemp)
had_dotenv=false

if [[ -f apps/frontend/.env ]]; then
  cp apps/frontend/.env "$dotenv_backup"
  had_dotenv=true
fi

cleanup() {
  "${compose[@]}" down --volumes --remove-orphans || true
  if [[ "$had_dotenv" == true ]]; then
    cp "$dotenv_backup" apps/frontend/.env
  else
    rm -f apps/frontend/.env
  fi
  rm -f "$dotenv_backup"
}
trap cleanup EXIT

cp dev-frontend.env apps/frontend/.env

docker build --tag laravel_app_dev:1.0 --file Containerfile .
docker build --tag go_hello:1.0 --file apps/go-hello/Containerfile apps/go-hello

"${compose[@]}" up -d apps caddy buggregator kividb rustfs go-hello

wait_for() {
  local name="$1"
  shift

  for attempt in $(seq 1 180); do
    if "$@" >/dev/null 2>&1; then
      echo "$name is ready"
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for $name" >&2
  "${compose[@]}" ps >&2
  "${compose[@]}" logs --no-color >&2
  return 1
}

check_laravel_bootstrap() {
  "${compose[@]}" exec -T apps php artisan --version
}
wait_for "Laravel dependencies" check_laravel_bootstrap

"${compose[@]}" exec -T apps php artisan key:generate --force
"${compose[@]}" exec -T apps php artisan migrate --force

wait_for "Laravel through Caddy" curl --fail --silent http://localhost:8080/
wait_for "RustFS S3 API" curl --fail --silent http://localhost:9000/health
wait_for "Buggregator" curl --fail --silent http://localhost:8000/

check_kividb() {
  "${compose[@]}" exec -T -e REDIS_PASSWORD="$REDIS_PASSWORD" apps php -r '
$redis = new Redis();
$redis->connect("kividb", 6379);
if (!$redis->auth(getenv("REDIS_PASSWORD")) || $redis->ping() === false) {
    exit(1);
}
'
}
wait_for "KiviDB authenticated connection" check_kividb

"${compose[@]}" exec -T apps php artisan cache:put e2e:cache connected 60
cache_value=$("${compose[@]}" exec -T apps php artisan cache:get e2e:cache)
if [[ "$cache_value" != "connected" ]]; then
  echo "Laravel cache did not round-trip through KiviDB" >&2
  exit 1
fi

docker run --rm --network app_dev \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  amazon/aws-cli:2 \
  s3api create-bucket --bucket "$AWS_BUCKET" --endpoint-url http://rustfs:9000 --region "$AWS_DEFAULT_REGION"

"${compose[@]}" exec -T apps php artisan app:test-put-file-command
object_size=$(docker run --rm --network app_dev \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  amazon/aws-cli:2 \
  s3api head-object --bucket "$AWS_BUCKET" --key first.txt \
    --endpoint-url http://rustfs:9000 --region "$AWS_DEFAULT_REGION" \
    --query ContentLength --output text)
if [[ "$object_size" != "12" ]]; then
  echo "Laravel did not write the expected object to RustFS" >&2
  exit 1
fi

mail_response=$(curl --fail --silent http://localhost:8080/start-test-mail)
if [[ "$mail_response" != "OK" ]]; then
  echo "Laravel email request did not complete through Buggregator" >&2
  exit 1
fi

"${compose[@]}" up -d queue
job_response=$(curl --fail --silent http://localhost:8080/start-test-job)
if [[ "$job_response" != "OK" ]]; then
  echo "Laravel failed to dispatch the Horizon job" >&2
  exit 1
fi
horizon_job_completed() {
  curl --fail --silent http://localhost:8080/horizon/api/jobs/completed \
    | grep -Fq 'App\\Jobs\\TestJob'
}
wait_for "Horizon job completion" horizon_job_completed

rpc_output=$(timeout 30s "${compose[@]}" exec -T apps php artisan app:test-go-rpc 1)
if ! grep -q "Current date is" <<<"$rpc_output"; then
  echo "Laravel did not receive a response from Go RPC" >&2
  echo "$rpc_output" >&2
  exit 1
fi

echo "Full-stack end-to-end checks passed"
