#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/functions.sh"
source "$SCRIPT_DIR/../utils/variables.sh"

# NFS settings
NFS_SERVER_IP=$(cfg_map nfs ip)

# Create namespace
kubectl create namespace "$JUPYTERHUB_NAMESPACE"

# Create NFS provisioner and storage class
helm upgrade --install nfs-subdir-external-provisioner \
    nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server="$NFS_SERVER_IP" \
    --set nfs.path="$NFS_EXPORT"
kubectl apply -f "$SCRIPT_DIR/storage.yaml" -n "$JUPYTERHUB_NAMESPACE"

# Create/refresh the Kubernetes TLS secret from the Let's Encrypt certificates
kubectl create secret tls jupyterhub-tls \
    --cert="$SCRIPT_DIR/jupyter-crt.pem" \
    --key="$SCRIPT_DIR/jupyter-key.pem" \
    -n "$JUPYTERHUB_NAMESPACE"

# Launch JupyterHub
helm upgrade --cleanup-on-fail --install jupyterhub jupyterhub/jupyterhub \
    --namespace "$JUPYTERHUB_NAMESPACE" \
    --values "$SCRIPT_DIR/config.yaml"
