#!/bin/zsh

# Attach an interactive shell to the running Vivado container.
# Run this from ghostty (or any local terminal) while the container is up.

if ! docker ps --format '{{.Names}}' | grep -q '^vivado_container$'; then
    echo "vivado_container is not running. Start it first with: bash scripts/start_container.sh"
    exit 1
fi

exec docker exec -it -u user -e HOME=/home/user -w /home/user \
    vivado_container bash --rcfile /home/user/scripts/container_bashrc
