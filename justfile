set dotenv-path := "dev.env"

pull:
    - podman pull docker.io/library/caddy:latest
    - podman pull ghcr.io/buggregator/server:latest
    - podman pull docker.io/library/redis:latest
    - podman pull docker.io/minio/minio:latest

build:
    - podman build --force-rm --load --tag laravel_app_dev:1.0 .
    - podman image prune -f

install:
    - podman exec -it apps_dev sh -c 'composer install && php artisan telescope:publish'
    - podman exec -it apps_dev php artisan key:generate
    - podman exec -it apps_dev php artisan migrate --force

up:
    - podman-compose up -d

queue:
    - podman exec -it apps_dev php artisan horizon

down:
    - podman-compose down

deno-install:
    - cd apps/frontend && deno install

deno-dev: deno-install
    - cd apps/frontend && deno task dev

deno-prod: deno-install
    - cd apps/frontend && deno task build

lang-update:
    - podman exec -it apps_dev php artisan lang:update

check-code:
    - podman exec -it apps_dev sh check-code.sh

test:
    - podman exec -it apps_dev php artisan test

check-security:
    - podman exec -it apps_dev security-checker security:check composer.lock
    - podman exec -it apps_dev composer audit

logs:
    - podman-compose logs -f

console:
    - podman exec -it apps_dev sh

lint:
    - podman run --rm -i docker.io/hadolint/hadolint < Containerfile
    - podman run --rm -i docker.io/hadolint/hadolint < Containerfile.deno

build-deno-image:
    - podman build -f Containerfile.deno --tag deno_dev:1.0 .

update-frontend: build-deno-image
    - podman run --rm -it -v ./apps/frontend:/app/frontend deno_dev:1.0 sh -c "deno run -A npm:npm-check-updates --format group -i"

install-dockerfmt:
    - go install github.com/reteps/dockerfmt@latest

install-dprint:
    - cargo install --locked dprint

fmt:
    - podman run --rm -v .:/code -i docker.io/library/caddy:alpine caddy validate --config /code/Caddyfile
    - podman run --rm -v .:/code -i docker.io/library/caddy:alpine caddy fmt --overwrite /code/Caddyfile
    - just --fmt --unstable
    - dockerfmt --write Containerfile
    - dockerfmt --write Containerfile.deno
    - dprint fmt
