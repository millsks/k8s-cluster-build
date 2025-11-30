# K8s Component Architecture Diagram

This document expands on the high-level network topology with labeled Kubernetes components and supporting services. It’s intended as a quick reference for how traffic flows through the cluster and where each subsystem runs.

## Logical Component View

```text
+--------------------------------------------------------------------------------+
|                              External Clients                                  |
|                        (Browser, CLI, CI/CD, etc.)                             |
+-------------------------------+------------------------------------------------+
                                |
                                v
+-------------------------------+------------------------------------------------+
|                       Home Router / Switch (L2/L3)                             |
|                            Gateway: 172.16.0.1                                 |
+-------------------------------+------------------------------------------------+
                                |
                                v
+----------------------------------------------------------------------------------+
|                  Cluster Data Plane (LAN)  --  Subnet: 172.16.0.0/24             |
|                                                                                  |
|  +----------------------+   +----------------------+   +----------------------+  |
|  | k8s-control          |   | k8s-node1            |   | k8s-node2            |  |
|  | 172.16.0.10          |   | 172.16.0.11          |   | 172.16.0.12          |  |
|  | AMD 3400GE           |   | AMD 3400GE           |   | AMD 3400GE           |  |
|  | 32GB RAM             |   | 32GB RAM             |   | 32GB RAM             |  |
|  | 1TB NVMe SSD         |   | 1TB NVMe SSD         |   | 1TB NVMe SSD         |  |
|  +----------------------+   +----------------------+   +----------------------+  |
|                                                                                  |
+-------------------------------+--------------------------------------------------+
                                |
                                v
            +---------------------------------------------------------------+
            |                     Control Plane (logical)                   |
            |  kube-apiserver   etcd (embedded)   controller-manager        |
            |  scheduler        coredns (addon)   metrics-server (opt.)     |
            +---------------------------------------------------------------+
                                |
                                v
            +---------------------------------------------------------------+
            |                    Flannel CNI (overlay)                      |
            |                    Pod network: 10.244.0.0/16                 |
            +---------------------------------------------------------------+
                                |
                                v
+--------------------------+                 +--------------------------------+
| Kubernetes Services      | <---------------| Load Balancing & Ingress Layer |
| (ClusterIP / NodePort /  |                 |  MetalLB IP Pool:              |
|  LoadBalancer)           |                 |  172.16.0.240 - 172.16.0.250   |
|                          |                 |  NGINX Ingress Controller      |
+--------------------------+                 +--------------------------------+
                                ^
                                |
                                |
+-----------------------------------------------------------------------------+
|                               Storage Options                               |
|  - NFS-backed PVs (Synology DS925+ NAS)                                     |
|    * Hardware: 4x 14TB WD Red Pro NAS drives                                |
|  - Longhorn / OpenEBS (replicated block storage via CSI)                    |
+-----------------------------------------------------------------------------+
```

Notes on diagram:
- Connections shown top-to-bottom represent typical request and control/data flow:
  External Clients -> Router -> LAN -> Control Plane & Workers -> Flannel overlay -> Pods/Services.
- MetalLB + Ingress are presented as the external-facing load balancing/ingress layer.
- Storage options are shown as logical backends accessible to the worker nodes via CSI/NFS.

## Traffic Flows (Typical)

1) kubectl / API requests:
   - Client -> `kube-apiserver` on k8s-control -> persisted state in `etcd`.

2) Pod-to-pod networking:
   - Pods communicate across nodes via Flannel overlay (10.244.0.0/16).
   - `kube-proxy` programs iptables/ipvs rules for Service VIPs.

3) External access to Services:
   - NodePort: client hits any node’s `<nodeIP>:<nodePort>`.
   - MetalLB (planned): assigns IPs from 172.16.0.240-172.16.0.250 to `LoadBalancer` Services.

4) Ingress (planned):
   - External -> Ingress IP/hostname -> NGINX Ingress Controller -> Service -> Pods.

5) Storage (options):
   - NFS: PVs backed by Synology DS925+ NAS (4x 14TB WD Red Pro drives).
   - Longhorn/OpenEBS: local or replicated block storage across nodes (CSI).

## Detailed ASCII Diagram (Planned State With MetalLB + Ingress)

```text
Internet / LAN Clients
       |
       v
+----------------------+
|  MetalLB IP Pool     |  e.g., 172.16.0.240-172.16.0.250
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
    +------+-----+                  +-----+------+
    |   Pods /   |                  |   Pods /   |
    | Deployments|                  | Deployments|
    +------------+                  +------------+

Under the hood on each node:
+-----------------------------------------------------------+
| kubelet | kube-proxy | Flannel (CNI) | CSI (storage, opt) |
+-----------------------------------------------------------+
```

## Nodes and Responsibilities

- k8s-control (172.16.0.10)
  - Hardware: AMD 3400GE, 32GB RAM, 1TB NVMe SSD
  - kube-apiserver, controller-manager, scheduler
  - etcd (embedded single-node)
  - coredns, metrics-server (optional)
  - Acts as the management endpoint for kubectl

- k8s-node1 (172.16.0.11)
  - Hardware: AMD 3400GE, 32GB RAM, 1TB NVMe SSD
  - Runs workloads
  - kubelet, kube-proxy, Flannel (CNI)
  - CSI components if storage stack is deployed

- k8s-node2 (172.16.0.12)
  - Hardware: AMD 3400GE, 32GB RAM, 1TB NVMe SSD
  - Runs workloads
  - kubelet, kube-proxy, Flannel (CNI)
  - CSI components if storage stack is deployed

## Planned Add-ons and Addressing

- CNI: Flannel (10.244.0.0/16) for pod network
- MetalLB: 172.16.0.240–172.16.0.250 reserved for `LoadBalancer` Services
- Ingress: NGINX Ingress Controller
- Storage:
  - Option A: NFS-backed PVs via Synology DS925+ NAS (4x 14TB WD Red Pro drives)
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
