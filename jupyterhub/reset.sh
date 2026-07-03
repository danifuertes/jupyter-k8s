#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/variables.sh"

# Stop JupyterHub
helm delete jupyterhub -n "$JUPYTERHUB_NAMESPACE"

# Remove NFS provisioner and its storage class
helm delete nfs-subdir-external-provisioner
kubectl delete sc nfs-sc -n "$JUPYTERHUB_NAMESPACE"

# Remove Kubernetes secret
kubectl delete secret/jupyterhub-tls -n "$JUPYTERHUB_NAMESPACE"

# Remove namespace
kubectl delete namespace "$JUPYTERHUB_NAMESPACE"
