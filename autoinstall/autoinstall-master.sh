#!/bin/bash
set -e  # Exit on any error

# Load shared utilities and cluster configuration (node lists, users)
source "$(dirname "$0")/../utils/functions.sh"

# Trap any script error and print a banner
trap 'handle_failure $LINENO' ERR

# Worker nodes (names), read from inputs.yaml
mapfile -t NODES < <(cfg_node_names workers)

# Disable swap
swapoff -a

# Move to tmp to make the installation
cd /tmp

# Update and upgrade packages
apt update && apt upgrade -y

# Install aptitude
apt install -y aptitude
handle_success "aptitude"

# Install socat
apt install -y socat
handle_success "socat"

# Install Docker
apt-get update
apt-get install -y ca-certificates curl gpg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# groupadd docker
usermod -aG docker "$(cfg_cluster master_user)"
# newgrp docker
systemctl enable docker.service
systemctl enable containerd.service
handle_success "docker"

# Install CUDA drivers
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update
apt-get install -y cuda-toolkit-12-6
apt-get install -y cuda-drivers
handle_success "cuda-drivers"

# Install NVIDIA container runtime with Docker
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
	gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
	&& curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
	sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
	tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker
cat <<EOF > /etc/docker/daemon.json
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
EOF
handle_success "nvidia-container-toolkit"

# Install Docker CRI
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.14/cri-dockerd_0.3.14.3-0.ubuntu-jammy_amd64.deb ###### CAMBIAR JAMMY POR LO QUE TOQUE 
dpkg -i cri-dockerd_0.3.14.3-0.ubuntu-jammy_amd64.deb
handle_success "docker CRI"

# Install Kubectl, Kubeadm, and Kubelet v1.30
apt-get install -y apt-transport-https
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
	gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
	tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl kubelet kubeadm
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet
handle_success "kubectl"
handle_success "kubelet"
handle_success "kubeadm"

# Install SSH server
apt-get update
apt-get install -y openssh-server
handle_success "openssh-server"

# TODO: Add pc01-pc16 to .ssh/config & ssh-keygen & ssh-copy-id pc01-pc16

# Install NFS server
apt-get install -y nfs-kernel-server
systemctl start nfs-kernel-server.service
mkdir -p /srv/nfs/kubernetes
chown nobody:nogroup /srv/nfs/kubernetes
chmod 777 /srv/nfs/kubernetes
# Build the NFS export allow-list from the worker nodes in inputs.yaml
{
    echo
    echo "# Kubernetes cluster"
    for node in "${NODES[@]}"; do
        echo "/srv/nfs/kubernetes        ${node}(rw,sync,no_subtree_check)"
    done
} >> /etc/exports
exportfs -ra
systemctl restart nfs-kernel-server
handle_success "nfs-kernel-server"

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/HEAD/scripts/get-helm-3 | bash
handle_success "helm"

# Install Jupyterhub
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
handle_success "jupyterhub"

# Install NFS external provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
handle_success "nfs-subdir-external-provisioner"

# Install NVITOP
apt-get update
apt-get install -y nvitop
handle_success "nvitop"

# Install VSCode
sudo apt-get install -y wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
sudo apt install -y apt-transport-https
sudo apt update
sudo apt install code # or code-insiders
handle_success "vscode"
