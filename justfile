set dotenv-path := "dev-frontend.env"

engine := env_var_or_default("CONTAINER_ENGINE", "podman")
compose := if engine == "docker" { "docker compose" } else { "podman-compose" }

pull:
    - {{engine}} pull docker.io/library/caddy:latest
    - {{engine}} pull ghcr.io/buggregator/server:latest
    - {{engine}} pull ghcr.io/kividbio/kividb:v1.1.0-lua
    - {{engine}} pull docker.io/rustfs/rustfs:latest

build:
    - {{engine}} build --force-rm --tag laravel_app_dev:1.0 .
    - {{engine}} image prune -f

install:
    - {{engine}} exec -it apps_dev sh -c 'composer install && php artisan telescope:publish'
    - {{engine}} exec -it apps_dev php artisan key:generate
    - {{engine}} exec -it apps_dev php artisan migrate --force

up:
    - {{compose}} up -d

queue:
    - {{engine}} exec -it apps_dev php artisan horizon

down:
    - {{compose}} down

deno-install:
    - cd apps/frontend && deno install

deno-dev: deno-install
    - cd apps/frontend && deno task dev

deno-prod: deno-install
    - cd apps/frontend && deno task build

lang-update:
    - {{engine}} exec -it apps_dev php artisan lang:update

check-code:
    - {{engine}} exec -it apps_dev sh check-code.sh

test:
    - {{engine}} exec -it apps_dev php artisan test

check-security:
    - {{engine}} exec -it apps_dev security-checker security:check composer.lock
    - {{engine}} exec -it apps_dev composer audit

logs:
    - {{compose}} logs -f

console:
    - {{engine}} exec -it apps_dev sh

lint:
    - {{engine}} run --rm -i docker.io/hadolint/hadolint < Containerfile
    - {{engine}} run --rm -i docker.io/hadolint/hadolint < Containerfile.deno

build-deno-image:
    - {{engine}} build -f Containerfile.deno --tag deno_dev:1.0 .

update-frontend: build-deno-image
    - {{engine}} run --rm -it -v "$PWD/apps/frontend:/app/frontend" deno_dev:1.0 sh -c "deno run -A npm:npm-check-updates --format group -i"

install-dockerfmt:
    - go install github.com/reteps/dockerfmt@latest

install-dprint:
    - cargo install --locked dprint

fmt:
    - {{engine}} run --rm -v "$PWD:/code" -i docker.io/library/caddy:alpine caddy validate --config /code/Caddyfile
    - {{engine}} run --rm -v "$PWD:/code" -i docker.io/library/caddy:alpine caddy fmt --overwrite /code/Caddyfile
    - just --fmt --unstable
    - dockerfmt --write Containerfile
    - dockerfmt --write Containerfile.deno
    - dprint fmt
