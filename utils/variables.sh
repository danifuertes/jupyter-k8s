#!/bin/bash
# ---------------------------------------------------------------------------
# Semi-hardcoded cluster variables.
#
# These are infrastructure defaults that rarely change and are the same for
# any deployment.
#
# Source this file from a script:  source "$(dirname "$0")/../utils/variables.sh"
# ---------------------------------------------------------------------------

# Kubernetes version
K8S_VERSION="v1.30.2"

# CRI socket for cri-dockerd (Docker as the container runtime)
CRI_SOCKET="unix:///var/run/cri-dockerd.sock"

# Pod network CIDR. Must match the CIDR configured in the Calico manifest (cluster/external-daemons/calico.yaml)
POD_NETWORK_CIDR="192.168.0.0/16"

# NFS share exported by the master and the mount point used on every node
NFS_EXPORT="/srv/nfs/kubernetes"
NFS_MOUNT="/mnt/nfs/kubernetes"

# Kubernetes namespace where JupyterHub and its storage are deployed
JUPYTERHUB_NAMESPACE="jk8s"
