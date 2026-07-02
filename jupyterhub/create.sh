#!/bin/bash

# Resolve this script's directory so it can be run from anywhere, and load utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/functions.sh"
source "$SCRIPT_DIR/../utils/variables.sh"

# NFS server IP: this node (the master) unless overridden with --nfs_server.
IP_NFS_SERVER=$(ip -br a | awk -v iface="$NET_INTERFACE" '$1 == iface {print $3}' | cut -d'/' -f1)

usage() {
    echo "Usage: $0 [--nfs_server <nfs-server-ip>]"
    exit 1
}

# Parse arguments
if [[ $# -gt 0 ]]; then
    case $1 in
        --nfs_server)
            [[ -z $2 ]] && { echo "Error: --nfs_server requires an argument."; usage; }
            IP_NFS_SERVER=$2
            ;;
        *)
            usage
            ;;
    esac
fi

if [[ -z "$IP_NFS_SERVER" ]]; then
    echo "ERROR: could not determine the NFS server IP (interface '$NET_INTERFACE')." >&2
    echo "       Pass it explicitly with:  $0 --nfs_server <ip>" >&2
    exit 1
fi

# Get JupyterHub settings from config.yaml
HOSTNAME=$(cfg_map jupyterhub hostname)
IMAGE_NAME=$(cfg_map jupyterhub image_name)
IMAGE_TAG=$(cfg_map jupyterhub image_tag)
set_args=()
i=0
for user in $(cfg_scalar_list admins); do
    set_args+=(--set-string "hub.config.Authenticator.admin_users[$i]=$user")
    i=$((i + 1))
done
i=0
for user in $(cfg_scalar_list users); do
    set_args+=(--set-string "hub.config.Authenticator.allowed_users[$i]=$user")
    i=$((i + 1))
done

# Create namespace
kubectl create namespace "$JUPYTERHUB_NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create NFS provisioner and storage class
helm upgrade --install nfs-subdir-external-provisioner \
    nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server="$IP_NFS_SERVER" --set nfs.path="$NFS_EXPORT"
kubectl apply -f "$SCRIPT_DIR/storage.yaml" -n "$JUPYTERHUB_NAMESPACE"

# Create/refresh the Kubernetes TLS secret from the Let's Encrypt certificates
kubectl create secret tls jupyterhub-tls \
    --cert="$SCRIPT_DIR/jupyter-crt.pem" --key="$SCRIPT_DIR/jupyter-key.pem" \
    -n "$JUPYTERHUB_NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Launch JupyterHub
helm upgrade --cleanup-on-fail --install jupyterhub jupyterhub/jupyterhub \
    --namespace "$JUPYTERHUB_NAMESPACE" \
    --values "$SCRIPT_DIR/config.yaml" \
    --set-string proxy.https.hosts[0]="$HOSTNAME" \
    --set-string singleuser.image.name="$IMAGE_NAME" \
    --set-string singleuser.image.tag="$IMAGE_TAG" \
    "${set_args[@]}"
