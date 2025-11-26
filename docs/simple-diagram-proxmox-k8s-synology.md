### Simple Diagram: Proxmox + K8s + Synology

```mermaid
graph TD
    subgraph Internet
        Router
    end

    subgraph Network Switch
        Router --- Switch
        Switch --- PVE1[Proxmox Node 1 (HP Mini)]
        Switch --- PVE2[Proxmox Node 2 (HP Mini)]
        Switch --- PVE3[Proxmox Node 3 (HP Mini)]
        Switch --- PVE4[Proxmox Node 4 (HP Mini)]
        Switch --- PVE5[Proxmox Node 5 (HP Mini)]
        Switch --- PVE6[Proxmox Node 6 (HP Mini)]
        Switch --- Synology[Synology DS925+]
    end

    subgraph Proxmox Cluster (6 HP Minis)
        PVE1 -- K8s Control Plane VM (cp-1) --> K8sCP1
        PVE1 -- K8s Worker VM (worker-1) --> K8sW1
        PVE2 -- K8s Control Plane VM (cp-2) --> K8sCP2
        PVE2 -- K8s Worker VM (worker-2) --> K8sW2
        PVE3 -- K8s Control Plane VM (cp-3) --> K8sCP3
        PVE3 -- K8s Worker VM (worker-3) --> K8sW3
        PVE4 -- K8s Worker VM (worker-4) --> K8sW4
        PVE5 -- K8s Worker VM (worker-5) --> K8sW5
        PVE6 -- K8s Worker VM (worker-6) --> K8sW6
    end

    subgraph Kubernetes Cluster (VMs)
        K8sCP1 -- K8s API --> K8sCP2
        K8sCP1 -- K8s API --> K8sCP3
        K8sCP2 -- K8s API --> K8sCP3
        K8sCP1 -- Pod Network --> K8sW1
        K8sW1 -- Pod Network --> K8sW2
        K8sW1 -- Pod Network --> K8sW3
        K8sW1 -- Pod Network --> K8sW4
        K8sW1 -- Pod Network --> K8sW5
        K8sW1 -- Pod Network --> K8sW6
    end

    subgraph Shared Storage
        Synology -- NFS/iSCSI --> PVE1
        Synology -- NFS/iSCSI --> PVE2
        Synology -- NFS/iSCSI --> PVE3
        Synology -- NFS/iSCSI --> PVE4
        Synology -- NFS/iSCSI --> PVE5
        Synology -- NFS/iSCSI --> PVE6
        Synology -- NFS/iSCSI (K8s PVs) --> K8sW1
        Synology -- NFS/iSCSI (K8s PVs) --> K8sW2
        Synology -- NFS/iSCSI (K8s PVs) --> K8sW3
        Synology -- NFS/iSCSI (K8s PVs) --> K8sW4
        Synology -- NFS/iSCSI (K8s PVs) --> K8sW5
        Synology -- NFS/iSCSI (K8s PVs) --> K8sW6
    end

    style PVE1 fill:#f9f,stroke:#333,stroke-width:2px
    style PVE2 fill:#f9f,stroke:#333,stroke-width:2px
    style PVE3 fill:#f9f,stroke:#333,stroke-width:2px
    style PVE4 fill:#f9f,stroke:#333,stroke-width:2px
    style PVE5 fill:#f9f,stroke:#333,stroke-width:2px
    style PVE6 fill:#f9f,stroke:#333,stroke-width:2px
    style Synology fill:#ccf,stroke:#333,stroke-width:2px
    style K8sCP1 fill:#afa,stroke:#333,stroke-width:2px
    style K8sCP2 fill:#afa,stroke:#333,stroke-width:2px
    style K8sCP3 fill:#afa,stroke:#333,stroke-width:2px
    style K8sW1 fill:#add,stroke:#333,stroke-width:2px
    style K8sW2 fill:#add,stroke:#333,stroke-width:2px
    style K8sW3 fill:#add,stroke:#333,stroke-width:2px
    style K8sW4 fill:#add,stroke:#333,stroke-width:2px
    style K8sW5 fill:#add,stroke:#333,stroke-width:2px
    style K8sW6 fill:#add,stroke:#333,stroke-width:2px
```

**Explanation of the Diagram:**

*   **Internet & Router:** Your gateway to the outside world.
*   **Network Switch:** The central hub connecting everything.
*   **Proxmox Nodes (HP Minis):** Your 6 physical machines, each running Proxmox VE. They form a single Proxmox cluster.
*   **Synology DS925+:** Your NAS, connected to the switch. It provides shared storage (NFS/iSCSI) to all Proxmox nodes.
*   **Kubernetes Control Plane VMs (K8sCP1-3):** Three VMs, each running on a different physical Proxmox node (PVE1-3) for high availability. They communicate with each other and the worker nodes.
*   **Kubernetes Worker VMs (K8sW1-6):** Six VMs, one on each physical Proxmox node (PVE1-6). These run your actual applications (pods).
*   **Connections:**
    *   All physical devices connect to the **Switch**.
    *   Proxmox nodes communicate with each other for **cluster management** and **VM migration**.
    *   Proxmox nodes access the **Synology** for VM storage.
    *   Kubernetes VMs communicate over the **Pod Network**.
    *   Kubernetes Worker VMs access the **Synology** for Persistent Volumes (PVs) for stateful applications.
