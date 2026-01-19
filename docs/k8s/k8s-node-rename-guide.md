# Kubernetes Control Plane Node Rename Guide

This document outlines the complete process of renaming a Kubernetes control plane node from `odin-k8s-cp01` to `odin-cp` and rejoining worker nodes.

## Initial State

```bash
kubectl get nodes
NAME            STATUS     ROLES           AGE   VERSION
huginn-wk       Ready      <none>          60s   v1.30.14
odin-k8s-cp01   NotReady   control-plane   12d   v1.30.14
```

## Prerequisites

- SSH access to the control plane node
- Cluster administrator privileges
- Backup of `/etc/kubernetes/` directory (recommended)
- Understanding that this process will temporarily disrupt the cluster

## Step-by-Step Process

### Step 1: Diagnose Drain Issues

First, we attempted to drain the node but encountered hanging. Investigation revealed static control plane pods and terminating pods:

```bash
# Check pods on the node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=odin-k8s-cp01

# Check for PodDisruptionBudgets
kubectl get pdb --all-namespaces

# Dry-run to see what would be drained
kubectl drain odin-k8s-cp01 --ignore-daemonsets --delete-emptydir-data --dry-run=client
```

**Result:** Found static control plane pods (etcd, kube-apiserver, kube-controller-manager, kube-scheduler) that cannot be evicted normally, and some pods stuck in Terminating state.

### Step 2: Delete the Node from Cluster

Since the node was NotReady and had static pods, we skipped the drain and directly deleted:

```bash
kubectl delete node odin-k8s-cp01
```

**Output:**
```
node "odin-k8s-cp01" deleted
```

### Step 3: Change System Hostname

On the control plane node (odin-cp), update the hostname:

```bash
# Set new hostname
sudo hostnamectl set-hostname odin-cp

# Update /etc/hosts file
sudo sed -i 's/odin-k8s-cp01/odin-cp/g' /etc/hosts

# Verify the change
hostnamectl
```

**Output:**
```
 Static hostname: odin-cp
       Icon name: computer-desktop
         Chassis: desktop 🖥️
      Machine ID: 1a3a4076ffbc44b291c1d94c252abb9b
         Boot ID: de48e58e8c924559b49d51e58bd9b754
Operating System: Ubuntu 24.04.3 LTS              
          Kernel: Linux 6.8.0-88-generic
    Architecture: x86-64
```

### Step 4: Reset Kubeadm Configuration

Clean up the old Kubernetes configuration:

```bash
# Reset kubeadm (will show warnings about stuck containers - this is normal)
sudo kubeadm reset --force
```

**Expected warnings:**
- Failed to remove some containers due to permission denied errors
- This is normal for stuck/terminating pods

**Manual cleanup required:**
```bash
# Clean up CNI configuration
sudo rm -rf /etc/cni/net.d

# Clean up kubeconfig
rm -rf $HOME/.kube

# Restart containerd to clear stuck containers
sudo systemctl restart containerd

# Clean up iptables rules
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```

### Step 5: Handle Port 6443 Conflict

If you encounter "Port 6443 is in use" error, kill lingering processes:

```bash
# Find and kill processes using port 6443
sudo lsof -ti:6443 | xargs sudo kill -9

# Kill any remaining kube processes
sudo pkill -9 kube-apiserver
sudo pkill -9 kube-controller
sudo pkill -9 kube-scheduler
sudo pkill -9 etcd

# Wait for processes to terminate
sleep 5
```

### Step 6: Reinitialize Kubernetes Cluster

Initialize the cluster with the new hostname:

```bash
sudo kubeadm init --control-plane-endpoint=odin-cp:6443 --pod-network-cidr=10.244.0.0/16 --upload-certs
```

**Key output details:**
- New certificates generated for `odin-cp`
- Bootstrap token created for joining nodes
- Control plane marked with new hostname

**Important information saved from output:**
- Worker join command with token
- Control plane join command (if adding more control planes)
- Certificate key (expires in 2 hours)

### Step 7: Configure kubectl for Regular User

Set up kubectl access:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Step 8: Install CNI Plugin (Flannel)

Deploy the pod network:

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

**Output:**
```
namespace/kube-flannel created
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
serviceaccount/flannel created
configmap/kube-flannel-cfg created
daemonset.apps/kube-flannel-ds created
```

### Step 9: Verify Control Plane Node

Check the node status:

```bash
kubectl get nodes
```

**Initial output (NotReady while Flannel starts):**
```
NAME      STATUS     ROLES           AGE   VERSION
odin-cp   NotReady   control-plane   5s    v1.30.14
```

Wait a moment for pods to start:

```bash
kubectl get pods -A
```

After Flannel pods are running:
```
NAME      STATUS   ROLES           AGE   VERSION
odin-cp   Ready    control-plane   117s  v1.30.14
```

### Step 10: Rejoin Worker Node (huginn-wk)

SSH into the worker node and reset it:

```bash
# Reset the worker node
sudo kubeadm reset --force

# Join using the token from kubeadm init output
sudo kubeadm join odin-cp:6443 --token b9zqxi.am5m8iu596exrd5k \
  --discovery-token-ca-cert-hash sha256:424b3d1d4845d710519c8431ca18d37ee5a92eaffbaf10031928199aba15c3c2
```

**Note:** Replace the token and discovery-token-ca-cert-hash with values from your `kubeadm init` output.

### Step 11: Final Verification

From the control plane node, verify all nodes are Ready:

```bash
kubectl get nodes
```

**Final output:**
```
NAME        STATUS   ROLES           AGE    VERSION
huginn-wk   Ready    <none>          16s    v1.30.14
odin-cp     Ready    control-plane   117s   v1.30.14
```

✅ **Success!** The control plane node has been renamed from `odin-k8s-cp01` to `odin-cp`, and the worker node has rejoined successfully.

## Optional: Add Worker Role Label

The `<none>` in the ROLES column is normal for worker nodes, but you can add a cosmetic label:

```bash
kubectl label node huginn-wk node-role.kubernetes.io/worker=worker
```

This will display:
```
NAME        STATUS   ROLES           AGE    VERSION
huginn-wk   Ready    worker          16s    v1.30.14
odin-cp     Ready    control-plane   117s   v1.30.14
```

## Troubleshooting

### Issue: Drain Hanging

**Symptoms:** `kubectl drain` command hangs indefinitely

**Causes:**
- Static control plane pods cannot be evicted
- Pods stuck in Terminating state
- PodDisruptionBudgets preventing eviction

**Solution:** Skip drain and proceed directly to node deletion when node is NotReady

### Issue: Port 6443 Already in Use

**Symptoms:** `kubeadm init` fails with port 6443 error

**Solution:**
```bash
sudo lsof -ti:6443 | xargs sudo kill -9
sudo pkill -9 kube-apiserver etcd kube-controller kube-scheduler
```

### Issue: Worker Node Won't Join

**Symptoms:** Join command fails or times out

**Possible causes:**
- Token expired (valid for 24 hours)
- Network connectivity issues
- Firewall blocking port 6443

**Solutions:**
- Generate new token: `kubeadm token create --print-join-command`
- Check connectivity: `nc -zv odin-cp 6443`
- Verify firewall rules allow port 6443

## Summary

This process successfully:
1. ✅ Deleted the old node `odin-k8s-cp01` from the cluster
2. ✅ Changed the system hostname to `odin-cp`
3. ✅ Reinitialized the Kubernetes cluster with new hostname
4. ✅ Rejoined the worker node `huginn-wk`
5. ✅ Verified cluster health and node readiness

**Total downtime:** Approximately 2-3 minutes from reset to cluster Ready state.

## Important Notes

- All pods and deployments need to be redeployed after cluster reinitialization
- Persistent volumes may need remapping
- Any services with node-specific configuration need updates
- Join tokens expire after 24 hours - save them if needed for additional nodes
- Certificate key for control plane joins expires after 2 hours

## References

- [Kubernetes kubeadm documentation](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [Flannel CNI plugin](https://github.com/flannel-io/flannel)
- [Troubleshooting kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)
