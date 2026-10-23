# Production

### Usage

```bash
# Select Docker; omit this to use Podman (the default).
export CONTAINER_ENGINE=docker

# Pull newer images
just pull

# Create prod image
just build

# Up containers
just up

# Migrate
just migrate

# Show logs
just logs

# Enter the apps container
just console

# Down containers
just down
```
