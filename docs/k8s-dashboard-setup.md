# Kubernetes Dashboard Setup Guide

This guide walks through installing and accessing the Kubernetes Dashboard web UI on a single-node control-plane cluster, including secure access via SSH port forwarding.

---

## Prerequisites

- A running Kubernetes cluster (single control-plane node or multi-node)
- `kubectl` configured and working
- SSH access to the control-plane node
- Control-plane node taint removed (for single-node clusters)

---

## Step 1: Remove Control-Plane Taint (Single-Node Clusters Only)

If you're running a single-node cluster, the control-plane taint prevents regular workloads from scheduling. Remove it:

```bash
kubectl taint nodes <node-name> node-role.kubernetes.io/control-plane:NoSchedule-
```

**Example:**
```bash
kubectl taint nodes odin-k8s-cp01 node-role.kubernetes.io/control-plane:NoSchedule-
```

**Expected output:**
```
node/odin-k8s-cp01 untainted
```

---

## Step 2: Install the Kubernetes Dashboard

Deploy the official Kubernetes Dashboard using the recommended manifest:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

**Expected output:**
```
namespace/kubernetes-dashboard created
serviceaccount/kubernetes-dashboard created
service/kubernetes-dashboard created
secret/kubernetes-dashboard-certs created
...
deployment.apps/kubernetes-dashboard created
```

---

## Step 3: Verify Dashboard Pods are Running

Check that the dashboard pods are running:

```bash
kubectl get pods -n kubernetes-dashboard
```

**Expected output:**
```
NAME                                         READY   STATUS    RESTARTS   AGE
dashboard-metrics-scraper-795895d745-xxxxx   1/1     Running   0          2m
kubernetes-dashboard-56cf4b97c5-xxxxx        1/1     Running   0          2m
```

If pods are stuck in `Pending`, verify you removed the control-plane taint in Step 1.

---

## Step 4: Create Admin Service Account

Create a service account with cluster-admin privileges for dashboard login:

```bash
kubectl create serviceaccount dashboard-admin-sa -n kubernetes-dashboard
```

```bash
kubectl create clusterrolebinding dashboard-admin-sa-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin-sa
```

**Expected output:**
```
serviceaccount/dashboard-admin-sa created
clusterrolebinding.rbac.authorization.k8s.io/dashboard-admin-sa-binding created
```

---

## Step 5: Generate Access Token

Generate a bearer token for the service account:

```bash
kubectl -n kubernetes-dashboard create token dashboard-admin-sa
```

**Expected output:**
```
eyJhbGciOiJSUzI1NiIsImtpZCI6ImlIa09RNGFvUERMeHdMN2kyRzdIVFZBbFJHdkI4MzJpYkZXckFXeUgtaVUifQ...
```

**⚠️ Important:** Copy this token — you'll need it to log into the dashboard.

---

## Step 6: Set Up SSH Port Forwarding

From your **local machine** (laptop/desktop), create an SSH tunnel to the control-plane node:

```bash
ssh -L 8001:localhost:8001 <username>@<control-plane-node-ip>
```

**Example:**
```bash
ssh -L 8001:localhost:8001 millsks@odin-k8s-cp01
```

Or if using an IP address:
```bash
ssh -L 8001:localhost:8001 millsks@192.168.86.51
```

**What this does:**
- Forwards local port `8001` on your machine to `localhost:8001` on the remote node
- Keeps the connection secure (HTTPS requirement for dashboard login)

**Keep this SSH session open** while you access the dashboard.

---

## Step 7: Start kubectl Proxy on the Remote Node

In the SSH session (on the control-plane node), start the kubectl proxy:

```bash
kubectl proxy
```

**Expected output:**
```
Starting to serve on 127.0.0.1:8001
```

**Leave this running** — do not close the terminal.

---

## Step 8: Access the Dashboard

On your **local machine**, open a web browser and navigate to:

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

You should see the Kubernetes Dashboard login page.

---

## Step 9: Log In with Token

1. Select **Token** as the authentication method
2. Paste the token you generated in Step 5
3. Click **Sign in**

You now have full cluster-admin access to the Kubernetes Dashboard!

---

## Dashboard Features

Once logged in, you can:

- **View all resources:** Pods, Services, Deployments, ConfigMaps, Secrets, etc.
- **Monitor cluster health:** Node status, resource usage, events
- **View logs:** Click any pod to see container logs
- **Exec into containers:** Use the shell icon to open a terminal inside a pod
- **Create/edit resources:** Deploy workloads using YAML or forms
- **Manage namespaces:** Switch between namespaces using the dropdown

---

## Troubleshooting

### Pods Stuck in Pending

**Symptom:**
```bash
kubectl get pods -n kubernetes-dashboard
NAME                                         READY   STATUS    RESTARTS   AGE
kubernetes-dashboard-56cf4b97c5-xxxxx        0/1     Pending   0          5m
```

**Solution:**  
Check for control-plane taint:
```bash
kubectl describe node <node-name> | grep -i taints
```

If you see `node-role.kubernetes.io/control-plane:NoSchedule`, remove it:
```bash
kubectl taint nodes <node-name> node-role.kubernetes.io/control-plane:NoSchedule-
```

---

### "Insecure access detected" Error

**Symptom:**  
Dashboard shows: *"Insecure access detected. Sign in will not be available."*

**Solution:**  
You must access the dashboard via `localhost` using SSH port forwarding (Steps 6-8). Direct access over HTTP from a remote IP will not allow login.

---

### No Endpoints Available (503 Error)

**Symptom:**
```json
{
  "kind": "Status",
  "message": "no endpoints available for service \"kubernetes-dashboard\"",
  "code": 503
}
```

**Solution:**  
Dashboard pods aren't running. Check pod status:
```bash
kubectl get pods -n kubernetes-dashboard
```

If not installed, run Step 2 again.

---

### Token Expired

**Symptom:**  
Login fails with authentication error.

**Solution:**  
Generate a new token:
```bash
kubectl -n kubernetes-dashboard create token dashboard-admin-sa
```

Tokens expire after 1 hour by default.

---

## Security Considerations

### ⚠️ Production Environments

The service account created in this guide has **cluster-admin** privileges, which grants full access to the cluster. For production:

1. **Use RBAC with least privilege:**  
   Create service accounts with limited permissions scoped to specific namespaces.

2. **Enable audit logging:**  
   Track all API requests made through the dashboard.

3. **Use external authentication:**  
   Integrate with OIDC providers (Google, Azure AD, Okta) instead of static tokens.

4. **Restrict network access:**  
   Use network policies or firewall rules to limit dashboard access.

5. **Consider alternatives:**  
   Tools like Lens Desktop, k9s, or Rancher provide secure multi-cluster management.

---

## Alternative Access Methods

### Option 1: NodePort Service (Less Secure)

Expose the dashboard via NodePort:
```bash
kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"type":"NodePort"}}'
```

Find the assigned port:
```bash
kubectl get svc -n kubernetes-dashboard
```

Access via:
```
https://<node-ip>:<nodeport>
```

**Note:** You'll need to accept the self-signed certificate warning.

---

### Option 2: Ingress with TLS

Set up an Ingress controller (e.g., NGINX) and expose the dashboard with a valid TLS certificate (Let's Encrypt).

---

## Stopping the Dashboard

To stop the kubectl proxy, press `Ctrl+C` in the terminal where it's running.

To uninstall the dashboard completely:
```bash
kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

To remove the service account and role binding:
```bash
kubectl delete clusterrolebinding dashboard-admin-sa-binding
kubectl delete serviceaccount dashboard-admin-sa -n kubernetes-dashboard
```

---

## Quick Reference Commands

```bash
# Check dashboard pods
kubectl get pods -n kubernetes-dashboard

# Check dashboard service
kubectl get svc -n kubernetes-dashboard

# Generate new token
kubectl -n kubernetes-dashboard create token dashboard-admin-sa

# Start proxy
kubectl proxy

# SSH tunnel (from local machine)
ssh -L 8001:localhost:8001 user@node-ip

# Dashboard URL
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

---

## Summary

You now have a fully functional Kubernetes Dashboard accessible securely via SSH port forwarding. This setup provides:

✅ Secure access through localhost  
✅ Full cluster visibility and management  
✅ No exposure to external networks  
✅ Easy token-based authentication  

For daily cluster management, consider also using:
- **k9s** for terminal-based management
- **Lens Desktop** for a rich GUI experience
- **kubectl** for command-line operations

Happy cluster managing! 🚀
