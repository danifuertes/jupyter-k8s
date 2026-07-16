# jupyter-k8s

Provision a bare-metal **Kubernetes** cluster and deploy a multi-user
**JupyterHub** on top of it. The stack ships with GPU support (NVIDIA device
plugin), NFS-backed persistent storage for user homes, and HTTPS via Let's
Encrypt.

---

## Architecture

| Component | Role |
|-----------|------|
| **Master node** | Kubernetes control plane (`kubeadm`), also the default NFS server |
| **Worker nodes** | Run the user pods; joined automatically over SSH |
| **NFS server** | Persistent storage for JupyterHub and user home directories |
| **Calico** | Pod networking |
| **NVIDIA device plugin** | Exposes GPUs to notebook pods |
| **JupyterHub** (Helm) | Multi-user notebook server, deployed in the `jk8s` namespace |

---

## Prerequisites

- One master and one or more worker nodes running Ubuntu, reachable over SSH.
- A DNS record (or static IP) pointing to the hub host, with **port 80 free**
  for certificate issuance.
- Cluster tooling installed on the nodes (Docker + cri-dockerd, kubeadm/kubelet/
  kubectl, Helm, NFS). The scripts in [`autoinstall/`](autoinstall/) automate
  this provisioning and SSH key distribution.

---

## Usage

### 1. Fill in `inputs.yaml`

Copy the template and edit it with your node names, IPs, users, hub hostname,
and JupyterHub options:

```bash
cp inputs.example.yaml inputs.yaml
```

See [inputs.example.yaml](inputs.example.yaml) for every available field. The
`jupyterhub:` section is passed straight through to the Helm chart as its values
file.

### 2. Obtain a TLS certificate

Request (or renew) a Let's Encrypt certificate for the hub host and place it
where the deployment expects it:

```bash
./certbot.sh
```

The host is read automatically from `inputs.yaml`. It must resolve to the
machine running the command, and port 80 must be free.

### 3. Launch the cluster

```bash
./launch-cluster.sh
```

This resets any previous cluster, initializes the control plane, applies
networking and the GPU plugin, joins every worker node over SSH, and installs
JupyterHub via Helm. When it finishes, the hub is reachable at
`https://<hub-hostname>`.

---

## Everyday operations

**Change JupyterHub configuration** — edit the `jupyterhub:` section of
`inputs.yaml`, then re-render and apply it:

```bash
./jupyterhub/update-config.sh   # regenerates jupyterhub/config.yaml
./jupyterhub/create.sh          # re-applies the Helm release
```

**Tear things down:**

```bash
./jupyterhub/reset.sh   # remove JupyterHub, storage and the TLS secret
./cluster/reset.sh      # reset the control plane and all worker nodes
```

**Build the notebook image** — the default single-user image (PyTorch + CUDA,
plus common data tooling) is defined in the [Dockerfile](Dockerfile). Build and
push it to a registry, then set `singleuser.image.name`/`tag` in `inputs.yaml`.

---

## Repository layout

```
inputs.example.yaml   Template for inputs.yaml (git-ignored)
certbot.sh            Issue/renew the Let's Encrypt certificate
launch-cluster.sh     One-shot: reset + create cluster + deploy JupyterHub
autoinstall/          Node provisioning and SSH key distribution
cluster/              Kubernetes control plane create/reset + network manifests
jupyterhub/           JupyterHub Helm deploy, config rendering, storage, reset
utils/                Shared shell helpers and infrastructure defaults
Dockerfile            Default single-user notebook image
```

---

## Configuration reference

Key infrastructure defaults live in [utils/variables.sh](utils/variables.sh)
(Kubernetes version, pod network CIDR, NFS paths, namespace) and rarely need to
change. JupyterHub chart options are documented in the
[Zero to JupyterHub](https://zero-to-jupyterhub.readthedocs.io/en/stable/resources/reference.html)
reference.
