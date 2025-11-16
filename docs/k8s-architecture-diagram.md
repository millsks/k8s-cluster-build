# K8s Component Architecture Diagram

This document expands on the high-level network topology with labeled Kubernetes components and supporting services. It’s intended as a quick reference for how traffic flows through the cluster and where each subsystem runs.

## Logical Component View

    +------------------------------------------------------------+
    |                        External Clients                    |
    |                 (Browser, CLI, CI/CD, etc.)                |
    +----------------------------+-------------------------------+
                                 |
                                 v
    +----------------------------+-------------------------------+
    |                  Home Router / Switch (L2/L3)              |
    |                    Gateway: 192.168.1.1                    |
    +----------------------------+-------------------------------+
                                 |
                                 v
    +----------------------------+-------------------------------+
    |                     Cluster Data Plane (LAN)               |
    |                      Subnet: 192.168.1.0/24                |
    +----------------------------+-------------------------------+
      |                       |                       |
      v                       v                       v

    [k8s-control]           [k8s-node1]              [k8s-node2]
    192.168.1.10            192.168.1.11             192.168.1.12
    AMD 3400GE / 32GB       AMD 3400GE / 32GB        AMD 3400GE / 32GB
    NVMe SSD                NVMe SSD                 NVMe SSD

    Control Plane (k8s-control):
    +-----------------------------------------------------------+
    | kube-apiserver  | etcd (embedded) | controller-manager    |
    | scheduler       | coredns (addon) | metrics-server (opt.) |
    +-----------------------------------------------------------+
                    |                                  ^
                    |                                  |
                    v                                  |
             Flannel CNI (overlay) --------------------+
                    |                                  |
                    v                                  |
             Pod-to-pod network (10.244.0.0/16)        |
                    |                                  |
    +-----------------------------------------------------------+
    | Workers: kubelet | kube-proxy | CNI (Flannel) | CSI (opt) |
    | - Runs user workloads (Deployments, DaemonSets, Jobs)     |
    | - NodePort/LoadBalancer Services exposed via:             |
    |     * NodePort (TCP/UDP)                                  |
    |     * MetalLB (allocates LAN IPs)                         |
    +-----------------------------------------------------------+

## Traffic Flows (Typical)

1) kubectl / API requests:
   - Client -> `kube-apiserver` on k8s-control -> persisted state in `etcd`.

2) Pod-to-pod networking:
   - Pods communicate across nodes via Flannel overlay (10.244.0.0/16).
   - `kube-proxy` programs iptables/ipvs rules for Service VIPs.

3) External access to Services:
   - NodePort: client hits any node’s `<nodeIP>:<nodePort>`.
   - MetalLB (planned): assigns IPs from 192.168.1.240-192.168.1.250 to `LoadBalancer` Services.

4) Ingress (planned):
   - External -> Ingress IP/hostname -> NGINX Ingress Controller -> Service -> Pods.

5) Storage (options):
   - NFS: PVs backed by NAS/export.
   - Longhorn/OpenEBS: local or replicated block storage across nodes (CSI).

## Detailed ASCII Diagram (Planned State With MetalLB + Ingress)

    Internet / LAN Clients
           |
           v
    +----------------------+
    |  MetalLB IP Pool     |  e.g., 192.168.1.240-192.168.1.250
    |  (LoadBalancer VIPs) |
    +-----+----------------+
          |
          v
    +----------------------+        +----------------------+
    |  NGINX Ingress Ctrl  | <----> |  Kubernetes Services |
    |  (DaemonSet/Deploy)  |        |  ClusterIP / NodePort|
    +----------+-----------+        +----------+-----------+
               |                               |
               v                               v
        +------+------+                  +-----+------+
        |   Pods /   |                  |   Pods /   |
        | Deployments|                  | Deployments|
        +------------+                  +------------+

    Under the hood on each node:
    +-----------------------------------------------------------+
    | kubelet | kube-proxy | Flannel (CNI) | CSI (storage, opt) |
    +-----------------------------------------------------------+

## Nodes and Responsibilities

- k8s-control (192.168.1.10)
  - kube-apiserver, controller-manager, scheduler
  - etcd (embedded single-node)
  - coredns, metrics-server (optional)
  - Acts as the management endpoint for kubectl

- k8s-node1 (192.168.1.11)
  - Runs workloads
  - kubelet, kube-proxy, Flannel (CNI)
  - CSI components if storage stack is deployed

- k8s-node2 (192.168.1.12)
  - Runs workloads
  - kubelet, kube-proxy, Flannel (CNI)
  - CSI components if storage stack is deployed

## Planned Add-ons and Addressing

- CNI: Flannel (10.244.0.0/16) for pod network
- MetalLB: 192.168.1.240–192.168.1.250 reserved for `LoadBalancer` Services
- Ingress: NGINX Ingress Controller
- Storage:
  - Option A: NFS-backed PVs via an external NAS
  - Option B: Longhorn with replicated volumes across worker nodes
- Monitoring:
  - Prometheus for metrics collection, Alertmanager for alerts
  - Grafana for dashboards

## Notes and Considerations

- Time sync: enable `systemd-timesyncd` or `chrony` on all nodes
- Kernel params: IP forwarding and bridge-nf sysctls enabled for Kubernetes
- Security: consider RBAC, restricted PSP/PodSecurity, network policies (if upgrading to Calico/Cilium)
- Upgrades: use `kubeadm upgrade` for orderly control-plane and node updates

## References

- Kubernetes Docs: https://kubernetes.io/docs/
- kubeadm Setup: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
- Flannel CNI: https://github.com/flannel-io/flannel
- MetalLB: https://metallb.universe.tf/
- NGINX Ingress: https://kubernetes.github.io/ingress-nginx/
- Longhorn: https://longhorn.io/
- Prometheus: https://prometheus.io/
- Grafana: https://grafana.com/
