#!/bin/bash

# Resolve this script's directory so it can be run from anywhere, and load utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/variables.sh"

# Best-effort teardown: keep going even if a resource is already gone, so the
# script is safe to re-run (helm has no --ignore-not-found, hence "|| true").

# Stop JupyterHub
helm delete jupyterhub -n "$JUPYTERHUB_NAMESPACE" || true

# Remove NFS provisioner (whole Helm release) and its storage class
helm delete nfs-subdir-external-provisioner || true
kubectl delete sc nfs-sc --ignore-not-found

# Remove Kubernetes secret with Let's Encrypt certificates
kubectl delete secret/jupyterhub-tls -n "$JUPYTERHUB_NAMESPACE" --ignore-not-found

# Remove namespace
kubectl delete namespace "$JUPYTERHUB_NAMESPACE" --ignore-not-found
