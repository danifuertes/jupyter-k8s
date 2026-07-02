#!/bin/bash
set -e  # Stop execution if any command fails

# Load shared utilities and cluster configuration (node lists, users)
source "$(dirname "$0")/../utils/functions.sh"

# Prompt for the sudo password
read -sp 'Enter your sudo password: ' PASSWORD
echo

# Variables (read from config.yaml — no hardcoded/sensitive values)
USERNAME="$(cfg_cluster master_user)"
# Target every master and worker node defined in the config
mapfile -t MACHINES < <(cfg_node_names masters; cfg_node_names workers)

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
    echo
    echo "Generating SSH key..."
    echo
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    if [ $? -ne 0 ]; then
        echo
        echo "Failed to generate SSH key."
        echo
        exit 1
    fi
else
    echo
    echo "SSH key already exists."
    echo
fi

# Install sshpass if not already installed (optional)
if ! command -v sshpass &> /dev/null; then
    echo
    echo "Installing sshpass..."
    echo
    sudo apt-get install -y sshpass
    if [ $? -ne 0 ]; then
        echo
        echo "Failed to install sshpass."
        echo
        exit 1
    fi
fi

# Copy SSH key to all target machines
for machine in "${MACHINES[@]}"; do
    echo
    echo "Copying SSH key to $machine..."
    echo
    sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "$USERNAME@$machine"
    if [ $? -ne 0 ]; then
        echo
        echo "Failed to copy SSH key to $machine."
        echo
        exit 1
    fi
done

echo
echo "################################################"
echo "# SSH key successfully copied to all machines! #"
echo "################################################"
echo
