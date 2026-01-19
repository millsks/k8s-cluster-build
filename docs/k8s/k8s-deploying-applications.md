# Kubernetes Application Deployment Guide

This guide covers how to deploy and manage applications on your Kubernetes cluster.

## Table of Contents

- [What You Can Do With Your Cluster](#what-you-can-do-with-your-cluster)
- [Deployment Methods](#deployment-methods)
- [Quick Start: Deploy Your First App](#quick-start-deploy-your-first-app)
- [Declarative Deployments (Recommended)](#declarative-deployments-recommended)
- [Service Types](#service-types)
- [Common kubectl Commands](#common-kubectl-commands)
- [Example Applications](#example-applications)
- [Next Steps](#next-steps)

---

## What You Can Do With Your Cluster

- **Deploy containerized applications** - Web apps, APIs, databases, microservices
- **Scale applications** - Horizontally across your 3 worker nodes
- **Load balance traffic** - Distribute requests across multiple pods
- **Manage configurations** - ConfigMaps and Secrets for application settings
- **Persistent storage** - Attach volumes for databases and stateful apps
- **Auto-healing** - Kubernetes restarts failed containers automatically
- **Rolling updates** - Deploy new versions with zero downtime
- **Resource management** - Set CPU/memory limits and requests

---

## Deployment Methods

### Imperative (Quick Testing)
Run commands directly - good for learning and quick tests:
```bash
kubectl create deployment myapp --image=nginx:latest
kubectl expose deployment myapp --port=80 --type=NodePort
```

### Declarative (Production Best Practice)
Use YAML manifests - version controlled, repeatable, auditable:
```bash
kubectl apply -f myapp-deployment.yaml
```

**Always use declarative approach for production workloads.**

---

## Quick Start: Deploy Your First App

### Step 1: Create a Deployment
```bash
kubectl create deployment nginx --image=nginx:latest
```

### Step 2: Verify It's Running
```bash
# Check pods
kubectl get pods

# Check deployment
kubectl get deployments

# Get detailed info
kubectl describe deployment nginx
```

### Step 3: Expose as a Service
```bash
kubectl expose deployment nginx --port=80 --type=NodePort
```

### Step 4: Access Your Application
```bash
# Get the assigned NodePort
kubectl get svc nginx

# Access via any worker node IP:NodePort
# Example: http://192.168.1.101:30080
```

### Step 5: Scale Your Application
```bash
# Scale to 3 replicas
kubectl scale deployment nginx --replicas=3

# Verify
kubectl get pods -o wide
```

### Step 6: Clean Up
```bash
kubectl delete service nginx
kubectl delete deployment nginx
```

---

## Declarative Deployments (Recommended)

### Basic Deployment Manifest

Create `nginx-deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

### Service Manifest

Create `nginx-service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    # nodePort: 30080  # Optional: specify port (30000-32767)
```

### Combined Manifest

You can combine multiple resources in one file using `---`:

Create `nginx-app.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

### Apply the Manifest
```bash
kubectl apply -f nginx-app.yaml
```

### Update the Application
Edit the YAML file and reapply:
```bash
kubectl apply -f nginx-app.yaml
```

---

## Service Types

### ClusterIP (Default)
- Only accessible within the cluster
- Use for internal microservices

```yaml
spec:
  type: ClusterIP
  ports:
  - port: 80
```

### NodePort
- Accessible on each node's IP at a static port (30000-32767)
- Good for development/testing

```yaml
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

### LoadBalancer
- Requires external load balancer (cloud or MetalLB)
- Provides external IP address
- Best for production

```yaml
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
```

---

## Common kubectl Commands

### Viewing Resources
```bash
# Get all resources in current namespace
kubectl get all

# Get specific resource types
kubectl get pods
kubectl get deployments
kubectl get services
kubectl get nodes

# Get resources in all namespaces
kubectl get pods --all-namespaces
kubectl get pods -A

# Wide output (more details)
kubectl get pods -o wide

# Watch for changes
kubectl get pods --watch
```

### Describing Resources
```bash
kubectl describe pod <pod-name>
kubectl describe deployment <deployment-name>
kubectl describe service <service-name>
kubectl describe node <node-name>
```

### Logs and Debugging
```bash
# View logs
kubectl logs <pod-name>

# Follow logs (tail -f)
kubectl logs -f <pod-name>

# Previous container logs (if crashed)
kubectl logs <pod-name> --previous

# Execute command in container
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec -it <pod-name> -- sh

# Port forward to local machine
kubectl port-forward <pod-name> 8080:80
kubectl port-forward service/<service-name> 8080:80
```

### Managing Resources
```bash
# Create from file
kubectl apply -f myapp.yaml

# Create from directory
kubectl apply -f ./manifests/

# Delete resources
kubectl delete -f myapp.yaml
kubectl delete deployment <name>
kubectl delete service <name>
kubectl delete pod <name>

# Scale deployment
kubectl scale deployment <name> --replicas=5

# Edit resource in-place
kubectl edit deployment <name>
```

### Updating Applications
```bash
# Update image
kubectl set image deployment/<name> <container-name>=<new-image>:tag

# Rollout status
kubectl rollout status deployment/<name>

# Rollout history
kubectl rollout history deployment/<name>

# Rollback
kubectl rollout undo deployment/<name>

# Rollback to specific revision
kubectl rollout undo deployment/<name> --to-revision=2
```

---

## Example Applications

### Example 1: Static Website (nginx)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: website
spec:
  replicas: 2
  selector:
    matchLabels:
      app: website
  template:
    metadata:
      labels:
        app: website
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: website-service
spec:
  type: NodePort
  selector:
    app: website
  ports:
  - port: 80
    targetPort: 80
```

### Example 2: Simple API Application

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: your-registry/api:v1.0.0
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: NodePort
  selector:
    app: api
  ports:
  - port: 3000
    targetPort: 3000
```

### Example 3: Application with ConfigMap

ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_host: "postgres-service"
  database_port: "5432"
  log_level: "info"
```

Deployment using ConfigMap:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:latest
        envFrom:
        - configMapRef:
            name: app-config
```

### Example 4: Application with Secrets

Create secret:
```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secretpassword
```

Use in deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

---

## Next Steps

### 1. Install MetalLB (Load Balancer)
Provides real IP addresses for LoadBalancer services instead of NodePort.

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

### 2. Set Up Ingress Controller
Route HTTP/HTTPS traffic to multiple services using hostnames/paths.

**nginx-ingress** or **Traefik** are popular choices.

### 3. Add Persistent Storage
Configure StorageClass for persistent volumes:
- NFS storage
- Local path provisioner
- Ceph/Rook

### 4. Install Monitoring Stack
- **Prometheus** - Metrics collection
- **Grafana** - Visualization
- **Alertmanager** - Alerts

### 5. Add Logging Solution
- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Loki** + Grafana
- **Fluentd/Fluent Bit**

### 6. Implement GitOps
- **ArgoCD** - Declarative continuous delivery
- **Flux** - GitOps operator

### 7. Set Up Cert-Manager
Automate TLS certificate management with Let's Encrypt.

### 8. Deploy Real Applications
Try deploying:
- WordPress (web + database)
- PostgreSQL/MySQL databases
- Redis cache
- Your own containerized applications

---

## Best Practices

1. **Always use resource limits** - Prevent pods from consuming all node resources
2. **Use namespaces** - Organize applications logically
3. **Version your manifests** - Store in Git for version control
4. **Use health checks** - Define liveness and readiness probes
5. **Don't use :latest tag** - Pin specific versions for reproducibility
6. **Use secrets for sensitive data** - Never hardcode credentials
7. **Label everything** - Makes resource management easier
8. **Plan for high availability** - Run multiple replicas
9. **Implement monitoring** - Know what's happening in your cluster
10. **Regular backups** - Backup cluster state and persistent data

---

## Troubleshooting

### Pod Not Starting
```bash
# Check pod status
kubectl get pods

# View detailed events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

### Service Not Accessible
```bash
# Verify service endpoints
kubectl get endpoints <service-name>

# Check service configuration
kubectl describe service <service-name>

# Test from within cluster
kubectl run test --rm -it --image=busybox -- wget -O- <service-name>
```

### Image Pull Errors
```bash
# Check if image exists and tag is correct
# Verify image registry credentials if using private registry
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password>
```

---

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Play with Kubernetes](https://labs.play-with-k8s.com/)
- [Kubernetes Patterns](https://github.com/k8spatterns/examples)

---

*Last updated: January 2026*
