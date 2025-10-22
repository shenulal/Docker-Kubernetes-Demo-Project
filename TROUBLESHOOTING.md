# Troubleshooting Guide

Common issues and solutions for the Docker & Kubernetes learning project.

## 🐳 Docker Issues

### 1. Docker Build Failures

#### Issue: "COPY failed: no such file or directory"
```bash
Error: COPY package*.json ./ - no such file or directory
```

**Solution:**
```bash
# Ensure you're in the project root directory
pwd  # Should show: /path/to/docker-kubernetes-poc

# Check if package.json exists
ls -la package.json

# Build from correct directory
docker build -t taskmanager-api .
```

#### Issue: "Permission denied" during build
```bash
Error: permission denied while trying to connect to Docker daemon
```

**Solution:**
```bash
# Add user to docker group (Linux/Mac)
sudo usermod -aG docker $USER
newgrp docker

# Or use sudo (not recommended for regular use)
sudo docker build -t taskmanager-api .
```

### 2. Docker Compose Issues

#### Issue: "Port already in use"
```bash
Error: bind: address already in use
```

**Solution:**
```bash
# Find process using the port
lsof -i :3000  # or netstat -tulpn | grep 3000

# Kill the process
kill -9 <PID>

# Or use different ports in docker-compose.yml
ports:
  - "3001:3000"  # Host:Container
```

#### Issue: "Database connection failed"
```bash
Error: connection to server at "postgres" (172.20.0.2), port 5432 failed
```

**Solution:**
```bash
# Check if PostgreSQL container is running
docker-compose ps

# Check PostgreSQL logs
docker-compose logs postgres

# Restart services with dependency order
docker-compose down
docker-compose up -d postgres
# Wait for PostgreSQL to be ready
docker-compose up -d api
```

## ☸️ Kubernetes Issues

### 1. Cluster Connection Issues

#### Issue: "Unable to connect to the server"
```bash
Error: Unable to connect to the server: dial tcp: lookup kubernetes.docker.internal
```

**Solution:**
```bash
# Check cluster status
kubectl cluster-info

# For minikube
minikube status
minikube start

# For Docker Desktop
# Enable Kubernetes in Docker Desktop settings

# For kind
kind get clusters
kind create cluster --name taskmanager-cluster
```

#### Issue: "No resources found"
```bash
Error: No resources found in taskmanager namespace
```

**Solution:**
```bash
# Check if namespace exists
kubectl get namespaces

# Create namespace if missing
kubectl apply -f k8s/namespace.yaml

# Check resources in all namespaces
kubectl get all --all-namespaces
```

### 2. Pod Issues

#### Issue: "ImagePullBackOff"
```bash
Status: ImagePullBackOff
```

**Solution:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n taskmanager

# Common fixes:
# 1. Build and tag image correctly
docker build -t taskmanager-api:latest .

# 2. For minikube, use minikube's Docker daemon
eval $(minikube docker-env)
docker build -t taskmanager-api:latest .

# 3. For kind, load image into cluster
kind load docker-image taskmanager-api:latest --name taskmanager-cluster

# 4. Update imagePullPolicy
kubectl patch deployment taskmanager-api-deployment -n taskmanager -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","imagePullPolicy":"Never"}]}}}}'
```

#### Issue: "CrashLoopBackOff"
```bash
Status: CrashLoopBackOff
```

**Solution:**
```bash
# Check pod logs
kubectl logs <pod-name> -n taskmanager

# Check previous container logs
kubectl logs <pod-name> -n taskmanager --previous

# Common causes and fixes:
# 1. Database not ready - check init container
kubectl describe pod <pod-name> -n taskmanager

# 2. Environment variables missing
kubectl get configmap taskmanager-config -n taskmanager -o yaml
kubectl get secret taskmanager-secrets -n taskmanager -o yaml

# 3. Health check failing
kubectl exec -it <pod-name> -n taskmanager -- curl localhost:3000/api/health
```

#### Issue: "Pending" pods
```bash
Status: Pending
```

**Solution:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n taskmanager

# Common causes:
# 1. Insufficient resources
kubectl top nodes
kubectl describe nodes

# 2. PVC not bound
kubectl get pvc -n taskmanager
kubectl describe pvc postgres-pvc -n taskmanager

# 3. Node selector issues
kubectl get nodes --show-labels
```

### 3. Service and Networking Issues

#### Issue: "Service not accessible"
```bash
curl: (7) Failed to connect to localhost port 8080
```

**Solution:**
```bash
# Check service status
kubectl get svc -n taskmanager

# Check endpoints
kubectl get endpoints -n taskmanager

# Port forward to test
kubectl port-forward svc/taskmanager-api-service 8080:80 -n taskmanager

# Check if pods are ready
kubectl get pods -n taskmanager
kubectl describe pod <pod-name> -n taskmanager
```

#### Issue: "DNS resolution failed"
```bash
Error: getaddrinfo ENOTFOUND postgres-service
```

**Solution:**
```bash
# Check service exists
kubectl get svc postgres-service -n taskmanager

# Test DNS from pod
kubectl exec -it <api-pod> -n taskmanager -- nslookup postgres-service

# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system <coredns-pod>
```

### 4. Storage Issues

#### Issue: "PVC stuck in Pending"
```bash
Status: Pending
```

**Solution:**
```bash
# Check PVC events
kubectl describe pvc postgres-pvc -n taskmanager

# Check storage class
kubectl get storageclass

# For local clusters, create a storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# Update PVC to use storage class
kubectl patch pvc postgres-pvc -n taskmanager -p '{"spec":{"storageClassName":"local-storage"}}'
```

### 5. HPA Issues

#### Issue: "HPA not scaling"
```bash
TARGETS: <unknown>/70%
```

**Solution:**
```bash
# Check metrics server
kubectl get pods -n kube-system | grep metrics-server

# Install metrics server if missing
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For local clusters, patch metrics server
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Check HPA status
kubectl describe hpa taskmanager-api-hpa -n taskmanager

# Generate load to test scaling
./scripts/load-test.sh http://localhost:8080 10 60 50
```

## 🔧 General Debugging

### 1. Useful Commands

```bash
# Check all resources
kubectl get all -n taskmanager

# Describe resources for events
kubectl describe <resource-type> <resource-name> -n taskmanager

# Check logs
kubectl logs -f deployment/taskmanager-api-deployment -n taskmanager

# Execute commands in pod
kubectl exec -it <pod-name> -n taskmanager -- /bin/sh

# Port forward for debugging
kubectl port-forward <pod-name> 3000:3000 -n taskmanager

# Check resource usage
kubectl top pods -n taskmanager
kubectl top nodes

# View events
kubectl get events -n taskmanager --sort-by='.lastTimestamp'
```

### 2. Environment-Specific Issues

#### minikube
```bash
# Start with more resources
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Enable addons
minikube addons enable metrics-server
minikube addons enable ingress

# Use minikube's Docker daemon
eval $(minikube docker-env)

# Get service URL
minikube service taskmanager-api-service -n taskmanager --url
```

#### kind
```bash
# Create cluster with config
kind create cluster --config=kind-config.yaml

# Load Docker image
kind load docker-image taskmanager-api:latest

# Port forward from host
kubectl port-forward svc/taskmanager-api-service 8080:80 -n taskmanager
```

#### Docker Desktop
```bash
# Enable Kubernetes in settings
# Use localhost for services with NodePort or port-forward

# Check Docker Desktop resources
# Increase memory/CPU if needed in settings
```

### 3. Performance Issues

#### High CPU/Memory Usage
```bash
# Check resource usage
kubectl top pods -n taskmanager

# Check resource limits
kubectl describe pod <pod-name> -n taskmanager

# Adjust resource limits
kubectl patch deployment taskmanager-api-deployment -n taskmanager -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","resources":{"limits":{"memory":"512Mi","cpu":"500m"}}}]}}}}'
```

#### Slow Database Queries
```bash
# Check PostgreSQL logs
kubectl logs deployment/postgres-deployment -n taskmanager

# Connect to database
kubectl exec -it deployment/postgres-deployment -n taskmanager -- psql -U postgres -d taskmanager

# Check database performance
\dt  -- List tables
\d tasks  -- Describe tasks table
EXPLAIN ANALYZE SELECT * FROM tasks;  -- Query performance
```

## 🆘 Getting Help

### 1. Check Logs First
```bash
# Application logs
kubectl logs -f deployment/taskmanager-api-deployment -n taskmanager

# Database logs
kubectl logs deployment/postgres-deployment -n taskmanager

# System logs
kubectl get events -n taskmanager --sort-by='.lastTimestamp'
```

### 2. Verify Configuration
```bash
# Check ConfigMap
kubectl get configmap taskmanager-config -n taskmanager -o yaml

# Check Secret (values are base64 encoded)
kubectl get secret taskmanager-secrets -n taskmanager -o yaml

# Decode secret values
kubectl get secret taskmanager-secrets -n taskmanager -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

### 3. Test Connectivity
```bash
# Test from outside cluster
curl http://localhost:8080/api/health

# Test from inside cluster
kubectl run test-pod --image=curlimages/curl -it --rm -- curl taskmanager-api-service.taskmanager.svc.cluster.local/api/health
```

### 4. Reset and Retry
```bash
# Clean restart
make clean-force
make build
make deploy

# Or step by step
kubectl delete namespace taskmanager
kubectl apply -f k8s/
```

## 📞 Community Resources

- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Docker Documentation**: https://docs.docker.com/
- **Stack Overflow**: Tag questions with `kubernetes`, `docker`
- **Kubernetes Slack**: https://kubernetes.slack.com/
- **GitHub Issues**: Report bugs in the project repository

Remember: Most issues are configuration-related. Double-check your YAML files, environment variables, and resource names!
