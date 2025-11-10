### Bare-Metal Kubernetes on 3 HP EliteDesk Minis

Set up a production-like, bare-metal Kubernetes cluster at home using three HP EliteDesk mini PCs: one control plane and two worker nodes. This guide targets Ubuntu Server 24.04 LTS, uses containerd as the runtime, and `kubeadm` for cluster bootstrap.

#### What You’ll Build
- 1 Control plane node: `k8s-control`
- 2 Worker nodes: `k8s-node1`, `k8s-node2`
- Pod network via Flannel (Calico is an alternative)
- Optional add-ons: MetalLB, NGINX Ingress, persistent storage

#### Hardware & Network Assumptions
- Each EliteDesk: 8GB+ RAM, 60GB+ storage, wired Ethernet
- Same LAN/subnet (e.g., `192.168.1.0/24`)
- BIOS: Virtualization enabled, UEFI, Secure Boot disabled
- You can SSH between nodes
- Either DHCP reservations or static IPs

---

### Architecture

| Role           | Hostname      | CPU | RAM | Storage | Notes                                      |
|----------------|---------------|-----|-----|---------|--------------------------------------------|
| Control Plane  | `k8s-control` | 2–4 | 8GB | 60GB+   | Runs API server, scheduler, controllers    |
| Worker         | `k8s-node1`   | 2–4 | 8GB | 60GB+   | Schedules workloads                        |
| Worker         | `k8s-node2`   | 2–4 | 8GB | 60GB+   | Schedules workloads                        |

---

### Step 1: Install Ubuntu Server 24.04 LTS

Perform these on each machine during OS install:
- Set hostname:
  - Control plane: `k8s-control`
  - Worker 1: `k8s-node1`
  - Worker 2: `k8s-node2`
- Install OpenSSH Server
- Configure static IPs if preferred (via Netplan) or set DHCP reservations
- Update and reboot:
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

Optional Netplan static IP example (adjust interface name/IPs):
```bash
sudo nano /etc/netplan/01-netcfg.yaml
```
```yaml
network:
  version: 2
  ethernets:
    eno1:
      addresses:
        - 192.168.1.10/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```
```bash
sudo netplan apply
```

---

### Step 2: Install containerd (all nodes)

```bash
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo systemctl enable --now containerd
```

Ensure systemd cgroups (recommended) in `/etc/containerd/config.toml`:
- Find the `SystemdCgroup` setting and set to `true` under `plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options`.

Example quick edit:
```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
```

---

### Step 3: Disable swap and configure kernel params (all nodes)

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system
```

---

### Step 4: Install kubeadm, kubelet, kubectl (all nodes)

Use the official Kubernetes apt repository.

```bash
sudo apt install -y apt-transport-https curl gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

---

### Step 5: Initialize the control plane (on `k8s-control` only)

Pick a Pod CIDR for your CNI. For Flannel, use `10.244.0.0/16`.

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

When it completes, copy the `kubeadm join` command it prints — you’ll need it for workers.

Configure kubectl for your user:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Verify node is seen (will be NotReady until CNI is installed):
```bash
kubectl get nodes
```

---

### Step 6: Install a Pod network (CNI) on the control plane

Flannel (simple, reliable for homelabs):
```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

Wait a minute or two, then:
```bash
kubectl get pods -n kube-system
kubectl get nodes
```
The control plane should transition to `Ready`.

Alternative: Calico (advanced policy, BGP support) — see Calico docs for the correct manifest for your K8s version.

---

### Step 7: Join worker nodes (`k8s-node1`, `k8s-node2`)

On each worker, run the `kubeadm join ...` command output by Step 5, for example:
```bash
sudo kubeadm join 192.168.1.10:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

Back on the control plane:
```bash
kubectl get nodes
```

Expected:
```
NAME          STATUS   ROLES           AGE   VERSION
k8s-control   Ready    control-plane   XXm   v1.30.x
k8s-node1     Ready    <none>          Xm    v1.30.x
k8s-node2     Ready    <none>          Xm    v1.30.x
```

---

### Step 8: Functional test

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get svc
```

Open in a browser:
```
http://<any-node-ip>:<nodePort>
```

You should see the default NGINX page.

---

### Optional Add‑Ons

#### Load Balancer for Services
Install MetalLB to support `LoadBalancer` Services on bare metal:
- Docs: [MetalLB](https://metallb.universe.tf/)
- Reserve an IP range in your LAN, e.g., `192.168.1.240-192.168.1.250`, and configure an IPAddressPool and L2Advertisement.

#### Ingress Controller
- NGINX Ingress: [Kubernetes Ingress NGINX](https://kubernetes.github.io/ingress-nginx/)
- Useful for routing HTTP/S traffic to multiple services on a single external IP

#### Persistent Storage
- NFS provisioner: simple and effective if you have a NAS
- Longhorn (distributed block storage): [Longhorn](https://longhorn.io) for easy dynamic PVCs on homelab hardware
- OpenEBS (LocalPV/ZFS): [OpenEBS](https://openebs.io/)

#### Observability
- Metrics Server:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
- Kubernetes Dashboard: [Dashboard](https://github.com/kubernetes/dashboard)
- Prometheus + Grafana stacks for full monitoring

---

### Maintenance

- Update packages periodically:
```bash
sudo apt update && sudo apt upgrade -y
```
- Hold/coordinate Kubernetes upgrades across nodes using `kubeadm upgrade`
- Snapshot or backup critical configs (e.g., `/etc/kubernetes/`, etcd via `etcdctl` for highly available control planes)

---

### Troubleshooting

- Control plane stays NotReady: CNI not installed or failing. Check `kubectl get pods -n kube-system` and logs.
- Workers won’t join: Token expired — create a new one:
```bash
kubeadm token create --print-join-command
```
- Pods can’t reach internet: Verify `net.ipv4.ip_forward=1` and CNI correctness; ensure gateway/DNS in Netplan.
- Secure Boot: Disable in BIOS or ensure signed modules are used.
- Time sync issues: Install and enable `systemd-timesyncd` or `chrony`.

---

### References

- Kubernetes official docs: [https://kubernetes.io/docs/](https://kubernetes.io/docs/)
- kubeadm getting started: [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- Flannel CNI: [https://github.com/flannel-io/flannel](https://github.com/flannel-io/flannel)
- Calico CNI: [https://docs.tigera.io/](https://docs.tigera.io/)
- MetalLB: [https://metallb.universe.tf/](https://metallb.universe.tf/)
- Longhorn: [https://longhorn.io/](https://longhorn.io/)

---

#### Notes
- For ultra-light clusters, consider k3s or MicroK8s. This guide focuses on upstream Kubernetes via `kubeadm` for the most “real” experience.
- If you later want high availability for the control plane, add additional control-plane nodes and front them with a virtual IP/load balancer.
