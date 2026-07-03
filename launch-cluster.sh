#!/bin/bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get sudo password
read -sp 'Enter sudo password: ' PASSWORD
echo
export PASSWORD

# Wait 30 seconds to ensure all nodes are working
echo "Waiting 30 seconds..."
sleep 30

# Launch Kubernetes cluster
cd "$ROOT_DIR/cluster"
./reset.sh
./create.sh

# Launch JupyterHub
cd "$ROOT_DIR/jupyterhub"
./create.sh
