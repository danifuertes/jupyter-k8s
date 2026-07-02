#!/bin/bash

# Resolve the repo root so it runs from anywhere
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared config helpers (cfg_node_names, ...) and validate config.yaml
source "$ROOT_DIR/utils/functions.sh"

# Get workers from config.yaml
WORKERS=$(cfg_node_names workers)
if [ -z "$WORKERS" ]; then
    echo "ERROR: no worker nodes found in $CONFIG_FILE" >&2
    exit 1
fi

# Get sudo password and share it with the sub-scripts
read -sp 'Enter sudo password: ' PASSWORD
echo
export PASSWORD

# Wait 30 seconds to ensure all nodes are working
echo "Waiting 30 seconds..."
sleep 30

# Launch Kubernetes cluster
cd "$ROOT_DIR/cluster"
./reset.sh $WORKERS
./create.sh $WORKERS

# Launch JupyterHub
cd "$ROOT_DIR/jupyterhub"
./create.sh
