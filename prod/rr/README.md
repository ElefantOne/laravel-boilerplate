# RoadRunner built by Velox

The RoadRunner binary is built inside a Go container, so the host only needs
Docker or Podman. The output is a Linux AMD64 binary in this directory.

Generate a GitHub token on https://github.com/settings/tokens?type=beta, then
build with the selected container engine (Podman by default):

```bash
export RT_TOKEN=...
export CONTAINER_ENGINE=${CONTAINER_ENGINE:-podman}
"$CONTAINER_ENGINE" build --file Containerfile --tag laravel-roadrunner-builder:1.0 .
"$CONTAINER_ENGINE" run --rm \
  --env RT_TOKEN \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  laravel-roadrunner-builder:1.0
```
