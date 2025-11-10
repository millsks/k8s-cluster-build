### Bare-Metal Kubernetes on 3 HP EliteDesk Minis
Set up a production-like, bare-metal Kubernetes cluster at home using three HP EliteDesk mini PCs: one control plane and two worker nodes. This guide targets Ubuntu Server 24.04 LTS, uses containerd as the runtime, and `kubeadm` for cluster bootstrap.

#### What You'll Build
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

| Role | Hostname | CPU | RAM | Storage | Notes |
|----------------|---------------|-----|-----|---------|--------------------------------------------|
| Control Plane | `k8s-control` | 2–4 | 8GB | 60GB+ | Runs API server, scheduler, controllers |
| Worker | `k8s-node1` | 2–4 | 8GB | 60GB+ | Schedules workloads |
| Worker | `k8s-node2` | 2–4 | 8GB | 60GB+ | Schedules workloads |

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
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
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

### Step 4.5: Install CNI plugins (all nodes)

**⚠️ IMPORTANT:** Standard CNI plugin binaries must be installed **before** initializing the cluster. These are separate from the CNI configuration that Flannel provides.

```bash
CNI_VERSION="v1.3.0"
sudo mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz" | \
  sudo tar -C /opt/cni/bin -xz
```

Verify installation:

```bash
ls /opt/cni/bin/
```

You should see: `loopback`, `bridge`, `host-local`, `portmap`, `bandwidth`, `firewall`, and others.

**Why this is needed:** Without these binaries, pods will fail to create with errors like:
```
failed to find plugin "loopback" in path [/opt/cni/bin]
```

---

### Step 5: Pre-flight checks (control plane only)

Before initializing, ensure no conflicting Kubernetes distributions are installed (e.g., MicroK8s, k3s):

```bash
# Check for port conflicts
sudo ss -ltnp '( sport = :6443 or sport = :10250 or sport = :10257 or sport = :10259 )'
```

If you see any processes (especially `kubelite` from MicroK8s), remove them:

```bash
# Remove MicroK8s if present
sudo snap remove microk8s

# Clean up any previous kubeadm state
sudo kubeadm reset -f
sudo rm -rf /var/lib/kubelet /etc/kubernetes /var/lib/etcd /etc/cni /var/lib/cni

# Verify ports are free
sudo ss -ltnp '( sport = :6443 or sport = :10250 or sport = :10257 or sport = :10259 )'
```

---

### Step 6: Initialize the control plane (on `k8s-control` only)

Pick a Pod CIDR for your CNI. For Flannel, use `10.244.0.0/16`.

#### Standard Single-Interface Setup

If you have a single network interface or want the API server to bind to the default route:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

#### Multi-Interface Setup (Separate Management and Cluster Networks)

**⚠️ IMPORTANT:** If your control plane has multiple network interfaces (e.g., Wi-Fi for internet access and wired Ethernet for cluster communication), you **must** specify which interface the API server should advertise on.

**Example scenario:**
- Wi-Fi interface (`wlp2s0`): `192.168.1.0/24` - Default route, internet access
- Wired interface (`enp3s0`): `172.16.0.0/16` - Dedicated cluster interconnect
- Pod network: `10.244.0.0/16` - Flannel overlay

**Why this matters:** Without `--apiserver-advertise-address`, kubeadm will bind the API server to the default route interface (Wi-Fi). Worker nodes on the wired network won't be able to reach the API server.

**Correct initialization command:**

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=172.16.0.10
```

Replace `172.16.0.10` with your control plane's static IP on the cluster interconnect network.

**Configure static IP on wired interface first:**

Edit `/etc/netplan/01-netcfg.yaml`:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:  # Replace with your wired interface name
      dhcp4: no
      addresses:
        - 172.16.0.10/16  # Control plane IP on cluster network
      # No gateway or nameservers - Wi-Fi handles internet
    wlp2s0:  # Wi-Fi interface (if applicable)
      dhcp4: yes
```

Apply the configuration:

```bash
sudo netplan apply
ip addr show enp3s0  # Verify the IP is assigned
```

When initialization completes, copy the `kubeadm join` command it prints — you'll need it for workers.

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

### Step 7: Install a Pod network (CNI) on the control plane

Flannel (simple, reliable for homelabs):

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

**If the node remains NotReady after installing Flannel:**

The container runtime may need to be restarted to pick up the CNI configuration:

```bash
# Restart containerd and kubelet
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

Wait a minute or two, then verify:

```bash
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel
kubectl get nodes
```

The control plane should transition to `Ready`, and CoreDNS pods should be `Running`.

**Verify Flannel interface:**

```bash
ip addr show flannel.1
```

You should see a `flannel.1` interface with an IP like `10.244.0.0/32`.

Alternative: Calico (advanced policy, BGP support) — see Calico docs for the correct manifest for your K8s version.

---

### Step 8: Join worker nodes (`k8s-node1`, `k8s-node2`)

**Before joining workers, ensure CNI plugins are installed on each worker node** (see Step 4.5).

On each worker, run the `kubeadm join ...` command output by Step 6, for example:

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

### Step 9: Functional test

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get svc
```

Open in a browser:

```
http://<node-ip>:<nodeport>
```

You should see the default NGINX page.

---

### Re-initializing the Cluster

If you need to re-initialize the cluster (e.g., to change the API server advertise address or fix a misconfiguration), follow these steps:

#### When to Re-initialize

- API server is bound to the wrong network interface
- Need to change pod network CIDR
- Cluster is in an unrecoverable state
- Testing different configurations

#### Re-initialization Process

**1. Reset the existing cluster:**

```bash
# Reset kubeadm
sudo kubeadm reset -f

# Clean up kubectl config
rm -rf $HOME/.kube

# Remove CNI configuration
sudo rm -rf /etc/cni/net.d

# Stop and restart kubelet
sudo systemctl stop kubelet
sudo systemctl start kubelet
```

**2. Verify ports are free:**

```bash
sudo ss -tulpn | grep -E ':(6443|2379|2380|10250|10259|10257)'
```

If any ports are still in use, identify and stop the processes:

```bash
# Find the process
sudo lsof -i :6443

# Stop kubelet if still running
sudo systemctl stop kubelet

# Check again
sudo ss -tulpn | grep -E ':(6443|2379|2380|10250|10259|10257)'
```

**3. Re-initialize with correct configuration:**

For multi-interface setup:

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=172.16.0.10
```

For standard setup:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

**4. Reconfigure kubectl:**

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**5. Reinstall Flannel:**

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

**6. Verify the new setup:**

```bash
# Check API server is listening on correct interface
sudo ss -tulpn | grep :6443

# Verify node status
kubectl get nodes

# Check all pods
kubectl get pods -A
```

**7. Rejoin worker nodes (if applicable):**

Generate a new join command:

```bash
kubeadm token create --print-join-command
```

On each worker node, reset and rejoin:

```bash
# Reset worker
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d

# Run the new join command
sudo kubeadm join 172.16.0.10:6443 --token <new-token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

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

#### Control plane stays NotReady

**Symptom:** Node shows `NotReady` status after `kubeadm init`.

**Check node conditions:**

```bash
kubectl describe node <node-name> | grep -A 10 "Conditions:"
```

**Common causes:**

1. **CNI not installed or failing**

```bash
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel
kubectl logs -n kube-flannel -l app=flannel
```

2. **Container runtime network not ready**

Error message: `container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized`

**Solution:** Restart containerd and kubelet:

```bash
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

3. **Missing CNI plugin binaries**

Error in pod events: `failed to find plugin "loopback" in path [/opt/cni/bin]`

**Solution:** Install CNI plugins (see Step 4.5):

```bash
ls /opt/cni/bin/  # Should show loopback, bridge, etc.
```

If missing, install them:

```bash
CNI_VERSION="v1.3.0"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz" | \
  sudo tar -C /opt/cni/bin -xz
sudo systemctl restart kubelet
```

#### Ports already in use during kubeadm init

**Symptom:** Error like `[ERROR Port-10250]: Port 10250 is in use`

**Check what's using the ports:**

```bash
sudo ss -ltnp '( sport = :10250 or sport = :10257 or sport = :10259 )'
```

**If MicroK8s or another K8s distribution is running:**

```bash
# Remove MicroK8s
sudo snap remove microk8s

# Or stop and reset kubeadm
sudo systemctl stop kubelet
sudo kubeadm reset -f
sudo rm -rf /var/lib/kubelet /etc/kubernetes /var/lib/etcd /etc/cni /var/lib/cni

# Flush iptables rules
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

# Verify ports are free
sudo ss -ltnp '( sport = :10250 or sport = :10257 or sport = :10259 )'
```

#### API Server on Wrong Interface

**Symptom:** API server is listening on Wi-Fi interface (`192.168.x.x`) instead of wired cluster network (`172.16.x.x`).

**Check which interface the API server is bound to:**

```bash
sudo ss -tulpn | grep :6443
```

**Cause:** `kubeadm init` was run without `--apiserver-advertise-address` flag, causing it to bind to the default route interface.

**Impact:**
- Worker nodes on the wired network cannot reach the API server
- Cluster communication goes over Wi-Fi instead of dedicated wired network
- Reduced performance and reliability

**Solution:** Re-initialize the cluster with the correct advertise address (see "Re-initializing the Cluster" section above).

#### Workers won't join

**Symptom:** Token expired or discovery fails.

**Solution:** Create a new join token:

```bash
kubeadm token create --print-join-command
```

#### Pods can't reach internet

- Verify `net.ipv4.ip_forward=1`:

```bash
sysctl net.ipv4.ip_forward
```

- Ensure gateway/DNS in Netplan
- Check CNI correctness and Flannel logs

#### CoreDNS pods stuck in ContainerCreating

**Check pod events:**

```bash
kubectl describe pod -n kube-system -l k8s-app=kube-dns | grep -A 10 Events
```

**Common cause:** Missing CNI plugin binaries (see "Missing CNI plugin binaries" above).

#### Secure Boot issues

- Disable Secure Boot in BIOS, or
- Ensure signed kernel modules are used

#### Time sync issues

Install and enable time synchronization:

```bash
sudo apt install -y systemd-timesyncd
sudo systemctl enable --now systemd-timesyncd
```

---

### Network Architecture Reference

When using the setup described in this guide, you'll have three distinct networks:

| Network | CIDR | Purpose | Used by |
|---------|------|---------|---------|
| **LAN/Wi-Fi** | `192.168.1.0/24` (example) | External access, management | SSH, kubectl from workstation |
| **Cluster interconnect** | Node IPs (e.g., `192.168.1.10-12` or `172.16.0.10-12`) | Node-to-node communication | kubelet, API server, etcd |
| **Pod network (Flannel)** | `10.244.0.0/16` | Pod-to-pod overlay network | CNI (VXLAN tunnels) |

These networks must not overlap. The pod network is a virtual overlay that runs on top of the cluster interconnect network.

#### Multi-Interface Network Architecture

For setups with separate management and cluster networks:

| Network | CIDR | Interface | Purpose |
|---------|------|-----------|---------|
| **Wi-Fi/Management** | `192.168.1.0/24` | `wlp2s0` | Internet access, external management |
| **Cluster Interconnect** | `172.16.0.0/16` | `enp3s0` | High-bandwidth node-to-node communication |
| **Pod Network** | `10.244.0.0/16` | `flannel.1` (virtual) | Pod-to-pod communication via VXLAN overlay |

**Benefits of separate networks:**
- Dedicated high-bandwidth path for cluster traffic
- Isolation of cluster communication from internet traffic
- Better security and performance
- Ability to use different physical switches/VLANs

**Important:** When using this setup, always specify `--apiserver-advertise-address` with the cluster interconnect IP during `kubeadm init`.

---

### References

- Kubernetes official docs: [https://kubernetes.io/docs/](https://kubernetes.io/docs/)
- kubeadm getting started: [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- Flannel CNI: [https://github.com/flannel-io/flannel](https://github.com/flannel-io/flannel)
- CNI plugins: [https://github.com/containernetworking/plugins](https://github.com/containernetworking/plugins)
- Calico CNI: [https://docs.tigera.io/](https://docs.tigera.io/)
- MetalLB: [https://metallb.universe.tf/](https://metallb.universe.tf/)
- Longhorn: [https://longhorn.io/](https://longhorn.io/)

---

#### Notes

- For ultra-light clusters, consider k3s or MicroK8s. This guide focuses on upstream Kubernetes via `kubeadm` for the most "real" experience.
- If you later want high availability for the control plane, add additional control-plane nodes and front them with a virtual IP/load balancer.
- **Always install CNI plugin binaries before running `kubeadm init`** to avoid pod creation failures.
- **For multi-interface setups, always specify `--apiserver-advertise-address`** to ensure the API server binds to the correct network interface.
