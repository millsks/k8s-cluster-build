# Proxmox + Kubernetes + Synology DS925+ Setup Checklist

This checklist assumes:
- 6× HP EliteDesk 705 G5 Mini PCs (Ryzen 5 PRO 3400GE, 32GB RAM, 1TB NVMe)
- 1× Synology DS925+ with 4×14TB drives
- Goal: Proxmox VE cluster + HA-ish Kubernetes cluster (VMs) + Synology for shared storage and backups.

---

## 1. Network & Infrastructure Prerequisites

- [ ] Ensure you have a **managed switch** (1 Gbit or better) with enough ports for:
  - [ ] 6× Proxmox nodes
  - [ ] 1× Synology DS925+
  - [ ] Router / firewall
- [ ] Decide IP ranges and addressing:
  - [ ] Management / Proxmox network (e.g. `192.168.10.0/24`)
  - [ ] Storage / NAS network (optional but recommended, e.g. `192.168.20.0/24`)
  - [ ] Kubernetes / node traffic (can be same as management initially)
- [ ] Assign **static IPs**:
  - [ ] 6× Proxmox hosts
  - [ ] Synology DS925+
  - [ ] Reserve IPs for:
    - [ ] Kubernetes API VIP or load balancer
    - [ ] Ingress/load balancer IP range (MetalLB, etc.)
- [ ] In each HP mini BIOS:
  - [ ] Enable **AMD-V / SVM (virtualization)**
  - [ ] Ensure **boot from NVMe** is enabled
  - [ ] Set boot order (USB first for installation, then NVMe)

---

## 2. Install Proxmox VE on Each Mini PC

For each of the 6 HP minis:

- [ ] Download latest **Proxmox VE ISO** from [https://www.proxmox.com](https://www.proxmox.com)
- [ ] Create a bootable USB using Rufus/Etcher/etc.
- [ ] Boot mini from USB and install Proxmox VE:
  - [ ] Select NVMe drive as install target
  - [ ] Use `ext4` or `ZFS` per preference (ext4 is fine to start)
  - [ ] Set a strong root password
  - [ ] Configure hostname (e.g. `pve1`, `pve2`, ... `pve6`)
  - [ ] Configure static IP from your management subnet
- [ ] After install, reboot and verify:
  - [ ] Access Proxmox web UI at `https://<proxmox-ip>:8006`
  - [ ] Accept self-signed certificate
  - [ ] Log in as `root` with your password

Repeat for all 6 nodes.

---

## 3. Create the Proxmox Cluster

On **pve1** (your first node):

- [ ] In web UI: `Datacenter -> Cluster -> Create Cluster`
  - [ ] Set Cluster Name (e.g. `homelab-cluster`)
  - [ ] Confirm network details

On **pve2–pve6**:

- [ ] In web UI: `Datacenter -> Cluster -> Join Cluster`
  - [ ] Paste join information from `pve1`
  - [ ] Provide `root` credentials
- [ ] Confirm that all **6 nodes appear** under `Datacenter -> Nodes`.

---

## 4. Configure Synology DS925+ (Storage Layer)

On the **DS925+** via DSM web UI:

- [ ] Initialize disks and create a storage pool:
  - [ ] Use **RAID 6** with 4×14TB for ~28TB usable
  - [ ] Use **Btrfs** filesystem
- [ ] Create a main volume on that pool.
- [ ] Set a **static IP** on the DS925+ in your storage/management subnet.

### 4.1 Create NFS Shares for Proxmox and Kubernetes

- [ ] Create shared folder `proxmox-vmstore`:
  - [ ] Enable **NFS** permissions for all 6 Proxmox node IPs
  - [ ] (Optional) Enable SMB for browsing
- [ ] Create shared folder `proxmox-backups`:
  - [ ] NFS/SMB for Proxmox backup storage
- [ ] Create shared folder `k8s-nfs`:
  - [ ] NFS export to be used by Kubernetes (NFS provisioner)

Note: Keep track of:
- [ ] NFS export paths (e.g. `/volume1/proxmox-vmstore`, etc.)
- [ ] DS925+ IP address

---

## 5. Add Synology NFS Storage to Proxmox

For each Proxmox node (or via Datacenter scope):

- [ ] In Proxmox UI: `Datacenter -> Storage -> Add -> NFS`
  - [ ] ID: `synology-vmstore`
  - [ ] Server: `<DS925+-IP>`
  - [ ] Export: `/volume1/proxmox-vmstore`
  - [ ] Content: `Disk image`, `ISO image`, `VZDump backup file` (as needed)
- [ ] (Optional) Add another NFS storage for `proxmox-backups`.
- [ ] Verify that all 6 nodes can see and use `synology-vmstore`.

---

## 6. Plan Kubernetes VMs (Topology & Sizing)

### 6.1 Kubernetes Topology

- [ ] 3× Control Plane VMs:
  - [ ] `cp-1` on `pve1`
  - [ ] `cp-2` on `pve2`
  - [ ] `cp-3` on `pve3`
- [ ] 6× Worker VMs:
  - [ ] `worker-1` on `pve1`
  - [ ] `worker-2` on `pve2`
  - [ ] `worker-3` on `pve3`
  - [ ] `worker-4` on `pve4`
  - [ ] `worker-5` on `pve5`
  - [ ] `worker-6` on `pve6`

### 6.2 VM Sizing (Initial)

- [ ] **Control plane VM spec (each):**
  - [ ] 2 vCPUs
  - [ ] 4–6 GB RAM
  - [ ] 40–60 GB disk (preferably on **local NVMe** of that node)
- [ ] **Worker VM spec (each):**
  - [ ] 4 vCPUs
  - [ ] 12–16 GB RAM
  - [ ] 80–120 GB disk (can be on **Synology NFS**)

---

## 7. Create Kubernetes VMs in Proxmox

For each planned VM (cp-1, cp-2, cp-3, worker-1..worker-6):

- [ ] In Proxmox UI: `Create VM`
  - [ ] Node: choose appropriate Proxmox host
  - [ ] Name: e.g. `cp-1`, `worker-1`
  - [ ] OS: use a lightweight Linux (e.g. Ubuntu Server, Debian)
  - [ ] System:
    - [ ] Use UEFI/BIOS as preferred
    - [ ] Enable `qemu-guest-agent` (install later inside VM)
  - [ ] Disks:
    - [ ] Storage: local NVMe for control planes; Synology NFS okay for workers
    - [ ] Size per spec above
  - [ ] CPU:
    - [ ] Type: `host` (for best performance)
    - [ ] Cores: 2 for control plane, 4 for workers
  - [ ] Memory:
    - [ ] As per spec (4–6 GB or 12–16 GB)
  - [ ] Network:
    - [ ] Attach to primary bridge (e.g. `vmbr0`)

- [ ] Install OS on each VM from ISO.
- [ ] Set static IPs for each VM in your node subnet.
- [ ] Set hostnames accordingly (`cp-1`, `worker-1`, etc.).

---

## 8. Install Kubernetes (kubeadm-based) on VMs

On all Kubernetes VMs (control plane and workers):

- [ ] Install container runtime (e.g. containerd or CRI-O).
- [ ] Install Kubernetes components:
  - [ ] `kubelet`
  - [ ] `kubeadm`
  - [ ] `kubectl`
- [ ] Disable swap (`swapoff -a` and comment swap in `/etc/fstab`).

### 8.1 Initialize the Control Plane

On `cp-1`:

- [ ] Run `kubeadm init` with appropriate parameters, e.g.:
  - [ ] `kubeadm init --control-plane-endpoint <k8s-api-vip-or-cp1-ip> --pod-network-cidr=<CIDR>`
- [ ] Save the **`kubeadm join` commands** printed for:
  - [ ] Additional control plane nodes
  - [ ] Worker nodes
- [ ] Configure `kubectl` for your user:
  - [ ] Copy `/etc/kubernetes/admin.conf` to `$HOME/.kube/config`

### 8.2 Install CNI (Pod Network)

On `cp-1` (or wherever you run `kubectl`):

- [ ] Install a CNI plugin (e.g. Calico, Cilium, Flannel):
  - [ ] Apply the CNI YAML manifest.
- [ ] Wait until `kubectl get nodes` shows `cp-1` as `Ready`.

### 8.3 Join Additional Control Planes and Workers

On `cp-2` and `cp-3`:

- [ ] Run `kubeadm join ... --control-plane ...` command from `kubeadm init` output.

On each worker VM:

- [ ] Run `kubeadm join ...` worker join command.

Verify:

- [ ] `kubectl get nodes` shows 3 control planes + 6 workers, all `Ready`.

---

## 9. Integrate Synology Storage with Kubernetes (NFS)

On one of the control plane nodes (where you use `kubectl`):

- [ ] Deploy NFS Subdir External Provisioner (or similar):
  - [ ] Create a `StorageClass` that points to the `k8s-nfs` NFS export on DS925+.
  - [ ] Configure:
    - [ ] NFS server: `<DS925+-IP>`
    - [ ] NFS path: `/volume1/k8s-nfs` (or your actual path)
- [ ] Mark this `StorageClass` as **default** if desired.

Validate:

- [ ] Create a test `PersistentVolumeClaim` using that `StorageClass`.
- [ ] Create a test Pod that writes data into that PVC.
- [ ] Confirm data appears in the Synology share.

---

## 10. Set Up Backups

### 10.1 Proxmox Backups

- [ ] (Optional but recommended) Deploy **Proxmox Backup Server**:
  - [ ] As a VM on one of the nodes or separate hardware
  - [ ] Use `proxmox-backups` NFS share as target storage
- [ ] Configure backups:
  - [ ] VM backup jobs for control planes and workers
  - [ ] Schedule daily/weekly backups

### 10.2 Kubernetes Object Backups (Optional)

- [ ] Consider installing **Velero** or similar to:
  - [ ] Backup Kubernetes manifests and PV data
  - [ ] Target Synology NFS or object storage provider

---

## 11. Monitoring and Ingress

- [ ] Deploy an ingress controller (e.g. NGINX Ingress, Traefik):
  - [ ] Configure a Service of type LoadBalancer (MetalLB) or NodePort
- [ ] Deploy MetalLB (if using bare-metal load balancing):
  - [ ] Configure address pool in your LAN subnet
- [ ] (Optional) Deploy basic monitoring stack:
  - [ ] Prometheus + Grafana
  - [ ] Node Exporter, kube-state-metrics

---

## 12. Final Validation Checklist

- [ ] Proxmox Cluster:
  - [ ] All 6 nodes `Online` in Proxmox UI
  - [ ] Synology NFS storage visible and usable from each node
- [ ] Kubernetes Cluster:
  - [ ] `kubectl get nodes` shows 3 control planes, 6 workers, all `Ready`
  - [ ] Pods from test deployments are `Running`
- [ ] Storage:
  - [ ] PVCs can be dynamically provisioned via `synology-nfs` StorageClass
  - [ ] Data written in pods appears on Synology
- [ ] Backups:
  - [ ] VM backups successfully run and are restorable
- [ ] Networking:
  - [ ] Ingress routes reachable from LAN
  - [ ] DNS and IPs consistent and documented

You now have a robust homelab platform: Proxmox cluster on 6 mini PCs, a Synology DS925+ providing shared storage and backups, and a multi-node Kubernetes cluster running as VMs on top.