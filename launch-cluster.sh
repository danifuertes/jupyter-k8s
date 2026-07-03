#!/bin/bash

# Resolve the repo root so it runs from anywhere, and load utils
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/utils/functions.sh"

# Get workers
WORKERS=$(cfg_node_names workers)
if [ -z "$WORKERS" ]; then
    echo "ERROR: no worker nodes found in $CONFIG_FILE" >&2
    exit 1
fi

# Get sudo password
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
