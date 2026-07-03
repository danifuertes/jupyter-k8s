#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/functions.sh"
source "$SCRIPT_DIR/../utils/variables.sh"

# Prompt for the sudo password
if [ -z "$PASSWORD" ]; then
    read -sp 'Enter your sudo password: ' PASSWORD
    echo
fi

# Get worker nodes
nodes=$(cfg_node_names workers)

# Get master nodes
IP_MASTER=$(cfg_nodes masters | awk 'NR==1 {print $2}')
if [ -z "$IP_MASTER" ]; then
    echo "ERROR: no master node found in $CONFIG_FILE" >&2
    exit 1
fi

# Get NFS server
IP_NFS_SERVER=$(cfg_nodes nfs | awk 'NR==1 {print $2}')
if [[ -z "$IP_NFS_SERVER" ]]; then
    IP_NFS_SERVER="$IP_MASTER"
fi

# Create cluster
echo
echo "Initializing Kubernetes cluster..."
echo $PASSWORD | sudo -S kubeadm init --kubernetes-version=$K8S_VERSION --cri-socket $CRI_SOCKET --pod-network-cidr=$POD_NETWORK_CIDR
if [ $? -ne 0 ]; then
    echo
    echo "Failed to initialize the Kubernetes cluster."
    echo
    exit 1
fi
echo

# Prepare permissions for kubectl
echo
echo "Setting up kubectl permissions..."
mkdir -p $HOME/.kube && \
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config
if [ $? -ne 0 ]; then
    echo
    echo "Failed to configure kubectl."
    echo
    exit 1
fi
echo

# Apply Calico networking manifest
echo
echo "Applying Calico network configuration..."
kubectl apply -f "$SCRIPT_DIR/external-daemons/calico.yaml"
if [ $? -ne 0 ]; then
    echo
    echo "Failed to apply Calico network configuration."
    echo
    exit 1
fi
echo

# Apply NVIDIA manifest to allow GPU usage
echo
echo "Applying NVIDIA device plugin for GPU..."
kubectl create -f "$SCRIPT_DIR/external-daemons/nvidia-device-plugin.yml"
if [ $? -ne 0 ]; then
    echo
    echo "Failed to apply NVIDIA device plugin configuration."
    echo
    exit 1
fi
echo

# Get join (join to the cluster) and mount (mount NFS) commands
token=$(kubeadm token create --print-join-command)
join_command="$token --cri-socket $CRI_SOCKET"
mount_command="if [ ! -d $NFS_MOUNT ]; then echo $PASSWORD | sudo -S mkdir -p $NFS_MOUNT; fi && echo $PASSWORD | sudo -S mount -t nfs4 $IP_NFS_SERVER:$NFS_EXPORT $NFS_MOUNT"
echo
echo "#################################"
echo "# Cluster created successfully! #"
echo "#################################"
echo

# Join the worker nodes (collected while parsing arguments) to the cluster
if [ -z "$nodes" ]; then
    echo
    echo "No worker nodes provided to join the cluster. Run these commands manually on the worker nodes:"
    echo
    echo "      $mount_command"
    echo
    echo "      sudo $join_command"
    echo
else
    echo
    echo "Joining the following nodes to the cluster in parallel:"
    echo
    echo "      $nodes"
    echo

    # Connect to each node in parallel
    for node in $nodes; do
        {
            # Mount NFS on each node
            echo
            echo "Mounting NFS on node $node..."
            ssh -t -o StrictHostKeyChecking=no $node "$mount_command"
            if [ $? -ne 0 ]; then
                echo
                echo "Failed to mount NFS on node $node."
                echo
                exit 1
            fi
            echo

            # Join each node to the cluster
            echo
            echo "Joining node $node to the cluster..."
            ssh -t -o StrictHostKeyChecking=no $node "echo $PASSWORD | sudo -S $join_command"
            if [ $? -ne 0 ]; then
                echo
                echo "Failed to join node $node to the cluster."
                echo
                exit 1
            fi
            echo

            # Label each node as a worker
            kubectl label node $node node-role.kubernetes.io/worker=worker
            if [ $? -ne 0 ]; then
                echo
                echo "Failed to label node $node as a worker."
                echo
                exit 1
            fi
            echo

            # Node successfully joined
            node_length=${#node}
            line=$(printf '#%.0s' $(seq 1 $((node_length + 42)))) # Create a line of '#' based on the node length
            echo
            echo "$line"
            echo "# Node $node successfully joined the cluster! #"
            echo "$line"
            echo
        } &
    done

    # Wait for all parallel jobs to finish
    wait
fi

echo
echo "Check if your nodes have successfully joined the cluster:"
echo
echo "        kubectl get nodes"
echo
