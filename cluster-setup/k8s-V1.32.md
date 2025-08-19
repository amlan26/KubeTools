# Kubernetes Single-Master Cluster Setup 🚀

![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.32-blue?logo=kubernetes&logoColor=white) ![Cilium](https://img.shields.io/badge/Cilium-1.17.0-blue?logo=cilium&logoColor=white)

This guide explains how to set up a **single-master Kubernetes cluster (v1.32)** using `kubeadm` and **Cilium** as the CNI plugin. Each command includes an **explanation** so beginners can follow along.

---

## Minimum Server Requirements

- **Master Node**: 2 vCPU, 2 GB RAM, 20 GB disk, Ubuntu 20.04/22.04
- **Worker Nodes**: 2 vCPU, 2 GB RAM, 20 GB disk, Ubuntu 20.04/22.04
- All nodes must have:
  - Internet access
  - Unique hostnames
  - Static IPs in the same subnet
  - Passwordless sudo enabled

---

## 1. Prepare All Nodes

Update and upgrade packages:
```bash
sudo apt update && sudo apt upgrade -y
```
👉 Keeps the system up to date with the latest patches and fixes.

Install required tools:
```bash
sudo apt install -y apt-transport-https ca-certificates curl gpg
```
👉 Needed to fetch Kubernetes repositories securely.

Disable swap (required by kubelet):
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```
👉 Ensures proper Kubernetes scheduling.

Enable kernel modules for networking:
```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```
👉 Required for Kubernetes networking and container isolation.

Set sysctl parameters:
```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```
👉 Allows packet forwarding and proper pod-to-pod communication.

---

## 2. Install Container Runtime (containerd)

```bash
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```
👉 containerd runs containers; this config ensures Kubernetes can manage pods.

Enable systemd cgroup driver:
```
SystemdCgroup = true
```
👉 Required by kubelet to match Kubernetes cgroup expectations.

Restart containerd:
```bash
sudo systemctl restart containerd
```

---

## 3. Install Kubernetes Components

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```
👉 Installs the main Kubernetes components and prevents accidental upgrades.

---

## 4. Initialize the Master Node

```bash
sudo kubeadm init \
  --apiserver-advertise-address=<MASTER_IP> \
  --pod-network-cidr=10.244.0.0/16
```
👉 Bootstraps the master node; pod CIDR must match Cilium's default.

Configure kubectl:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
👉 Allows your user to run kubectl commands.

Check cluster status:
```bash
kubectl get nodes
```

---

## 5. Install Cilium CNI

```bash
# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64; if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvf cilium-linux-${CLI_ARCH}.tar.gz -C /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Install Cilium into the cluster
cilium install --version 1.17.0
cilium status --wait
```
👉 Cilium provides networking, security, and visibility for pods.

Verify Cilium pods:
```bash
kubectl get pods -n kube-system -o wide
kubectl get nodes -o wide
```

---

## 6. Join Worker Nodes

Run the join command from `kubeadm init` output on each worker:
```bash
sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```
👉 Connects the worker nodes to the master node.

Regenerate join command if lost:
```bash
kubeadm token create --print-join-command
```

---

## 7. Verify Cluster

Check all nodes and pods:
```bash
kubectl get nodes -o wide
kubectl get pods -A
```
👉 Ensures master and workers are Ready and Cilium pods are running.

---

## 🎉 Cluster Ready!

Your Kubernetes cluster is now **up and running with Cilium networking**. ✅

