# 🧩 Bare-Metal Kubernetes Cluster (Home Lab)

[![Kubernetes](https://img.shields.io/badge/Kubernetes-Bare--Metal-blue?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-HP%20EliteDesk--Mini-lightgrey)]()
[![Docs](https://img.shields.io/badge/Documentation-Wiki-blue)](https://github.com/millsks/k8s-cluster-build/wiki)

A documentation and configuration repository for building and maintaining a **bare-metal Kubernetes cluster** in a **home lab environment**.  
This project chronicles the full setup, from initial hardware prep to multi-node cluster deployment, networking, and automated workloads — all running *without virtualization* on physical nodes.

---

## 🌐 Repository Overview

This repository contains:

| Directory / File | Description |
|------------------|-------------|
| `docs/` | Detailed setup documentation, network diagrams, and configuration notes |
| `config/` | Kubernetes manifests, kubeadm configs, and networking templates |
| `scripts/` | Helper scripts for provisioning, updates, and maintenance |
| `README.md` | High-level overview and project context (you are here) |
| `BRANCH-PROTECTION.md` | Quick guide for GitHub branch protection setup |
| `LICENSE` | Open-source license (MIT recommended) |

Additional deep-dive and step-by-step setup instructions are hosted in the [📖 Wiki](https://github.com/millsks/k8s-cluster-build/wiki).

---

## 🖧 Network & Cluster Topology

This home lab includes three physical HP EliteDesk Mini systems — one control plane and two worker nodes — all connected via a wired LAN.

```
                ┌──────────────────────────────┐
                │       Home Router/Switch     │
                │     172.16.0.1 (Gateway)     │
                └──────────────┬───────────────┘
                               │
                     ──────────┼───────────
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         │                     │                     │
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ k8s-control      │  │ k8s-node1        │  │ k8s-node2        │
│ Role: Control│   │  │ Role: Worker     │  │ Role: Worker     │
│ IP: 172.16.0.10  │  │ IP: 172.16.0.11  │  │ IP: 172.16.0.12  │
│ AMD Ryzen 5 PRO  │  │ AMD Ryzen 5 PRO  │  │ AMD Ryzen 5 PRO  │
│ 3400GE (4C/8T)   │  │ 3400GE (4C/8T)   │  │ 3400GE (4C/8T)   │
│ 32 GB RAM / NVMe │  │ 32 GB RAM / NVMe │  │ 32 GB RAM / NVMe │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                     │
         └───────────────────────────────────────────┘
         Kubernetes Pod Network (Flannel 10.244.0.0/16)
```

## 🧱 Cluster Architecture

**Hardware**: 3 × HP EliteDesk Mini PCs  
**Network**: Flat LAN (`172.16.0.0/24`) with static addressing  
**Operating System**: Ubuntu Server 24.04 LTS  
**Container Runtime**: containerd  
**Deployment Tool**: kubeadm  
**CNI**: Flannel (optionally Calico, Cilium later)  

| Role | Hostname | CPU | RAM | Storage | Notes |
|------|-----------|-----|-----|----------|-------|
| Control Plane | `k8s-control` | 4 | 8–16 GB | NVMe/SATA | API server, controller, scheduler |
| Worker Node 1 | `k8s-node1` | 4 | 8 GB | SSD | Runs pods/workloads |
| Worker Node 2 | `k8s-node2` | 4 | 8 GB | SSD | Runs pods/workloads |

---

## ⚙️ Key Features & Goals

- **Bare-metal cluster** — running directly on physical hardware (no Proxmox or VM layers)  
- **Production-like topology** — mirrors cloud Kubernetes environments for learning and testing  
- **Config-as-doc** — every configuration and command documented, versioned, and repeatable  
- **Continuous improvement** — evolving as more add-ons and advanced setups are tested:
  - MetalLB (bare-metal LoadBalancer)
  - NGINX Ingress Controller
  - Persistent storage (NFS, Longhorn, OpenEBS)
  - Prometheus & Grafana monitoring stack
  - GitOps via ArgoCD or Flux

---

## 🗂️ Documentation Topics

The [Wiki](https://github.com/millsks/k8s-cluster-build/wiki) and `/docs` directory track key milestones:

- 🖥️ **Hardware Prep** – BIOS setup, networking, static IP addressing  
- ⚙️ **Cluster Bootstrapping** – installing containerd, kubeadm, Flannel, and joining nodes  
- 🔄 **Lifecycle Management** – upgrades, node maintenance, snapshots/backups  
- ☸️ **Kubernetes Add-ons** – load balancer, ingress, persistent volumes, metrics  
- 📊 **Monitoring & Observability** – Prometheus, Grafana, and system-level insights  
- 🚀 **Workload Deployment Examples** – NGINX, sample microservices, GitOps workflows  

---

## 🧰 Tooling Used

| Tool / Stack | Purpose |
|---------------|----------|
| `Ubuntu Server 24.04` | Base OS (bare-metal install) |
| `containerd` | Container runtime |
| `kubeadm` | Cluster bootstrap & config |
| `kubectl` | Cluster management CLI |
| `Flannel` | Pod networking (CNI) |
| `MetalLB` | Bare-metal load balancing |
| `Helm` | Package management for add-ons |
| `Prometheus + Grafana` | Metrics & observability |
| `GitHub Actions` *(future)* | CI/CD for manifests |

---

## 🧪 Current Status

- ✅ Hardware configured and Ubuntu installed  
- ✅ Kubernetes v1.30 deployed via `kubeadm`  
- ✅ Flannel networking functional  
- 🧩 Next: Experimenting with MetalLB and NGINX Ingress  
- 📈 Future: Implement GitOps and full observability stack  

Track progress in the [Issues](https://github.com/millsks/k8s-cluster-build/issues) and [Project Board](https://github.com/millsks/k8s-cluster-build/projects).

---

## 🧭 Project Goals

- Learn and document **real-world Kubernetes cluster management**
- Build a reliable, local testbed for **DevOps automation and CI/CD**
- Serve as a **reference architecture** for others building homelab clusters
- Foster continuous learning through hands-on iteration and open documentation

---

## 🤝 Contributing

This is primarily a personal learning resource, but contributions and discussions are welcome!
- Open an [Issue](https://github.com/millsks/k8s-cluster-build/issues) for ideas, improvements, or troubleshooting
- Submit a PR for doc corrections or enhancements

### Repository Management

This repository uses branch protection to maintain code quality and prevent accidental changes to the main branch:
- 🛡️ Main branch is protected from deletion and force pushes
- 🔄 Feature branches and PRs are recommended for all changes
- 📋 See [BRANCH-PROTECTION.md](BRANCH-PROTECTION.md) for setup instructions and workflow guidelines

---

## 📜 License

This project is open-sourced under the [MIT License](LICENSE).

---

## 📸 Screenshots & Visuals (Coming Soon)

Planned additions:
- Cluster topology diagram (`docs/architecture-diagram.png`)
- Dashboard views and monitoring screenshots
- Real workload examples deployed on bare-metal

---

### 🧠 References

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [kubeadm Setup Guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Flannel CNI](https://github.com/flannel-io/flannel)
- [MetalLB](https://metallb.universe.tf/)
- [Longhorn Storage](https://longhorn.io/)
- [ArgoCD GitOps](https://argo-cd.readthedocs.io/)

---

> ⚡ **Follow the Journey** — Updates, experiments, and deep dives are logged here as this homelab evolves into a full-featured bare-metal Kubernetes environment.
