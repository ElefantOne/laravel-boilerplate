# RoadRunner built by Velox

The RoadRunner binary is built inside a Go container, so the host only needs
Docker or Podman. The output is a Linux AMD64 binary in this directory. Run
these commands from `prod/rr`:

Build without a GitHub token using Podman by default. Set `CONTAINER_ENGINE=docker`
to use Docker instead:

```bash
export CONTAINER_ENGINE=${CONTAINER_ENGINE:-podman}
"$CONTAINER_ENGINE" build --file Containerfile --tag laravel-roadrunner-builder:1.0 .
"$CONTAINER_ENGINE" run --rm \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  laravel-roadrunner-builder:1.0
```

`RT_TOKEN` is optional. For authenticated GitHub requests, export a token and
add `--env RT_TOKEN` to the `run` command. Unauthenticated builds can be subject
to GitHub's API rate limits.
