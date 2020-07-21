# Local dev

This is an initial attempt for local development. It is heavily based on
[jsonnet], [tanka] and [docker-compose]

## Prerequisites

- environment exported as defined by [.envrc](./.envrc) or [direnv]
- golang
- bash
- docker-compose

## Docker compose environments

```bash
# jdc is a wrapper around docker-compose and allows to use jsonnet to specify
# jsonnet and can be used like this
# jdc <PATH-TO-JSONNET> <DOCKER-COMPOSE COMMANDS>

# Create environment and watch logs
jdc jsonnet/docker-compose/cortex/main.jsonnet up

[...]

# Same in the background
jdc jsonnet/docker-compose/cortex/main.jsonnet up -d

# Now override cortex-mixin with local version
export JSONNET_PATH=$HOME/git/github.com/grafana/cortex-jsonnet:$JSONNET_PATH

# Restart containers
jdc jsonnet/docker-compose/cortex/main.jsonnet restart
```

[tanka]:https://tanka.dev
[jsonnet]:https://jsonnet.org/
[docker-compose]:https://docs.docker.com/compose/
[direnv]:https://direnv.net/
