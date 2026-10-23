#!/bin/sh
set -eu

engine=${CONTAINER_ENGINE:-podman}
image=laravel-roadrunner-builder:1.0

case "$engine" in
    docker|podman) ;;
    *) echo "CONTAINER_ENGINE must be docker or podman" >&2; exit 2 ;;
esac

if [ -z "${RT_TOKEN:-}" ]; then
    echo "RT_TOKEN is required to build RoadRunner" >&2
    exit 2
fi

"$engine" build --file Containerfile --tag "$image" .
"$engine" run --rm \
    --env RT_TOKEN \
    --volume "$PWD:/workspace" \
    --workdir /workspace \
    "$image" \
    sh -ec 'CGO_ENABLED=0 GOOS=linux GOARCH=amd64 vx build -c velox.toml -o . && strip -s ./rr && file ./rr'
