# RoadRunner built by Velox

The RoadRunner binary is built inside a Go container, so the host only needs
Docker or Podman. The output is a Linux AMD64 binary in this directory.

Generate a GitHub token on https://github.com/settings/tokens?type=beta, then
build with:

```bash
export RT_TOKEN=...
# Optional; defaults to podman. Set to docker to use Docker Engine.
export CONTAINER_ENGINE=docker
sh build.sh
```
