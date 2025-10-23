# Docker & Kubernetes Learning Project

A comprehensive hands-on example demonstrating Docker containerization and Kubernetes orchestration with a real-world Task Management API.

## 🎯 What You'll Learn

- **Docker**: Containerization, multi-stage builds, Docker Compose, best practices
- **Kubernetes**: Deployments, Services, ConfigMaps, Secrets, Persistent Volumes
- **Scalability**: Horizontal Pod Autoscaler (HPA), load balancing, resource management
- **Production Concepts**: Health checks, rolling updates, monitoring, troubleshooting

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   Ingress       │    │   External      │
│   (Cloud LB)    │────│   Controller    │────│   Traffic       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐
                       │   API Service   │
                       │   (ClusterIP)   │
                       └─────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌─────────────┐        ┌─────────────┐        ┌─────────────┐
│   API Pod   │        │   API Pod   │        │   API Pod   │
│   (Node.js) │        │   (Node.js) │        │   (Node.js) │
└─────────────┘        └─────────────┘        └─────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                       ┌─────────────────┐
                       │ PostgreSQL Svc  │
                       │   (ClusterIP)   │
                       └─────────────────┘
                                │
                       ┌─────────────────┐
                       │ PostgreSQL Pod  │
                       │   + PVC         │
                       └─────────────────┘
```

## 📋 Prerequisites

### Required Tools

1. **Docker** (v20.10+)
   ```bash
   # Install Docker Desktop or Docker Engine
   # Verify installation
   docker --version
   docker-compose --version
   ```

2. **Kubernetes Cluster**
   - **Local Development**: minikube, kind, or Docker Desktop
   - **Cloud**: EKS, GKE, AKS, or any managed Kubernetes

3. **kubectl** (Kubernetes CLI)
   ```bash
   # Install kubectl
   # Verify installation
   kubectl version --client
   ```

4. **Optional Tools**
   ```bash
   # For load testing
   go install github.com/rakyll/hey@latest
   
   # For monitoring
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

### Local Kubernetes Setup (Choose One)

#### Option 1: minikube
```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start --cpus=4 --memory=8192 --disk-size=20g
minikube addons enable metrics-server
minikube addons enable ingress
```

#### Option 2: kind (Kubernetes in Docker)
```bash
# Install kind
go install sigs.k8s.io/kind@latest

# Create cluster
kind create cluster --config=kind-config.yaml
```

#### Option 3: Docker Desktop
```bash
# Enable Kubernetes in Docker Desktop settings
# No additional setup required
```

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone https://github.com/shenulal/Docker-Kubernetes-Demo-Project.git
cd docker-kubernetes-poc

# Copy environment file
cp .env.example .env
```

### 2. Docker Development
```bash
# Install dependencies
npm install

# Start with Docker Compose
docker-compose up -d

# Check services
docker-compose ps
curl http://localhost:3000/api/health

# View logs
docker-compose logs -f api

# Stop services
docker-compose down
```

### 3. Build Production Image
```bash
# Build Docker image
chmod +x scripts/docker-build.sh
./scripts/docker-build.sh v1.0.0

# Or manually
docker build -t taskmanager-api:v1.0.0 .
```

### 4. Deploy to Kubernetes
```bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get all -n taskmanager

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=task-management-api -n taskmanager --timeout=300s

# Get service URL
kubectl get svc -n taskmanager
```

### 5. Test the API
```bash
# Port forward to access API
kubectl port-forward svc/taskmanager-api-service 8080:80 -n taskmanager

# Test endpoints
curl http://localhost:8080/api/health
curl http://localhost:8080/api/tasks

# Create a task
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Learn Kubernetes", "description": "Complete the tutorial"}'
```

## 📚 Detailed Walkthrough

### Step 1: Understanding the Application

The Task Management API is a Node.js REST API with:
- **CRUD operations** for tasks
- **PostgreSQL database** for persistence
- **Health check endpoints** for Kubernetes probes
- **Input validation** and error handling
- **Security middleware** (helmet, CORS, rate limiting)

**Key Files:**
- `src/server.js` - Main application server
- `src/routes/tasks.js` - Task API endpoints
- `src/routes/health.js` - Health check endpoints
- `src/database/init.js` - Database connection and initialization

### Step 2: Docker Implementation

#### Dockerfile Explained
```dockerfile
# Multi-stage build for optimization
FROM node:18-alpine AS builder
# ... build stage

FROM node:18-alpine AS production
# ... production stage with minimal footprint
```

**Key Concepts:**
- **Multi-stage builds** reduce final image size
- **Non-root user** improves security
- **Health checks** enable container monitoring
- **Proper signal handling** for graceful shutdown

#### Docker Compose for Development
```yaml
services:
  postgres:
    # Database service with health checks
  api:
    # API service depending on database
  pgadmin:
    # Optional database management UI
```

**Key Concepts:**
- **Service dependencies** with health checks
- **Named volumes** for data persistence
- **Custom networks** for service communication
- **Environment-specific overrides**

### Step 3: Kubernetes Deployment

#### Core Concepts

**Pod vs Container vs Deployment vs Service:**
- **Container**: Single application process
- **Pod**: One or more containers sharing network/storage
- **Deployment**: Manages multiple pod replicas
- **Service**: Stable network endpoint for pods

#### Resource Hierarchy
```
Namespace
├── ConfigMap (configuration)
├── Secret (sensitive data)
├── PersistentVolumeClaim (storage)
├── Deployment (pod management)
├── Service (networking)
├── Ingress (external access)
└── HorizontalPodAutoscaler (scaling)
```

#### Deployment Process
```bash
# 1. Create namespace
kubectl apply -f k8s/namespace.yaml

# 2. Create configuration
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# 3. Create storage
kubectl apply -f k8s/postgres-pvc.yaml

# 4. Deploy database
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml

# 5. Deploy API
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/api-service.yaml

# 6. Configure scaling
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/pod-disruption-budget.yaml

# 7. External access (choose one)
kubectl apply -f k8s/ingress.yaml
# OR for cloud environments
kubectl patch svc taskmanager-api-loadbalancer -n taskmanager -p '{"spec":{"type":"LoadBalancer"}}'
```

### Step 4: Scaling Demonstration

#### Horizontal Pod Autoscaler (HPA)
```bash
# Check HPA status
kubectl get hpa -n taskmanager

# Describe HPA for detailed info
kubectl describe hpa taskmanager-api-hpa -n taskmanager

# Run load test to trigger scaling
chmod +x scripts/load-test.sh
./scripts/load-test.sh http://localhost:8080 20 300 100
```

#### Manual Scaling
```bash
# Scale deployment manually
kubectl scale deployment taskmanager-api-deployment --replicas=5 -n taskmanager

# Check scaling status
kubectl get pods -n taskmanager -l app=task-management-api

# Scale down
kubectl scale deployment taskmanager-api-deployment --replicas=2 -n taskmanager
```

#### Resource Monitoring
```bash
# View resource usage
kubectl top pods -n taskmanager
kubectl top nodes

# Monitor in real-time
watch kubectl get pods -n taskmanager
```

## 🔧 Configuration Management

### Environment Variables

**ConfigMap** (non-sensitive):
- `NODE_ENV`, `PORT`
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`
- Application settings

**Secret** (sensitive):
- `DB_PASSWORD`
- `POSTGRES_PASSWORD`
- API keys, certificates

### Resource Limits

```yaml
resources:
  requests:    # Guaranteed resources
    memory: "128Mi"
    cpu: "100m"
  limits:      # Maximum resources
    memory: "256Mi"
    cpu: "200m"
```

**Best Practices:**
- Set requests for scheduling
- Set limits to prevent resource exhaustion
- Monitor actual usage to optimize

## 🚦 Health Checks

### Probe Types

1. **Liveness Probe**: Is the container alive?
   ```yaml
   livenessProbe:
     httpGet:
       path: /api/health/live
       port: 3000
   ```

2. **Readiness Probe**: Is the container ready for traffic?
   ```yaml
   readinessProbe:
     httpGet:
       path: /api/health/ready
       port: 3000
   ```

3. **Startup Probe**: Initial startup check
   ```yaml
   startupProbe:
     httpGet:
       path: /api/health/live
       port: 3000
     failureThreshold: 10
   ```

## 🔄 Rolling Updates

### Update Strategy
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1
    maxSurge: 1
```

### Performing Updates
```bash
# Update image
kubectl set image deployment/taskmanager-api-deployment api=taskmanager-api:v2.0.0 -n taskmanager

# Check rollout status
kubectl rollout status deployment/taskmanager-api-deployment -n taskmanager

# View rollout history
kubectl rollout history deployment/taskmanager-api-deployment -n taskmanager

# Rollback if needed
kubectl rollout undo deployment/taskmanager-api-deployment -n taskmanager
```

## 🌐 Networking

### Service Types

1. **ClusterIP** (default): Internal cluster access only
2. **NodePort**: Access via node IP:port
3. **LoadBalancer**: Cloud provider load balancer
4. **ExternalName**: DNS CNAME record

### Ingress Configuration
```yaml
# HTTP routing based on hostname/path
rules:
- host: api.example.com
  http:
    paths:
    - path: /
      backend:
        service:
          name: taskmanager-api-service
          port:
            number: 80
```

## 📊 Monitoring and Troubleshooting

### Common Commands
```bash
# Check pod status
kubectl get pods -n taskmanager

# View pod logs
kubectl logs -f deployment/taskmanager-api-deployment -n taskmanager

# Describe resources for events
kubectl describe pod <pod-name> -n taskmanager

# Execute commands in pod
kubectl exec -it <pod-name> -n taskmanager -- /bin/sh

# Port forward for debugging
kubectl port-forward pod/<pod-name> 3000:3000 -n taskmanager
```

### Common Issues

1. **ImagePullBackOff**
   ```bash
   # Check image name and availability
   kubectl describe pod <pod-name> -n taskmanager
   ```

2. **CrashLoopBackOff**
   ```bash
   # Check application logs
   kubectl logs <pod-name> -n taskmanager --previous
   ```

3. **Pending Pods**
   ```bash
   # Check resource availability
   kubectl describe pod <pod-name> -n taskmanager
   kubectl get nodes
   kubectl top nodes
   ```

## 🧪 Testing

### API Testing
```bash
# Health check
curl http://localhost:8080/api/health

# Create task
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task",
    "description": "Testing the API",
    "priority": "high"
  }'

# Get all tasks
curl http://localhost:8080/api/tasks

# Get task by ID
curl http://localhost:8080/api/tasks/1

# Update task
curl -X PUT http://localhost:8080/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'

# Delete task
curl -X DELETE http://localhost:8080/api/tasks/1

# Get statistics
curl http://localhost:8080/api/tasks/stats/summary
```

### Load Testing
```bash
# Using the provided script
./scripts/load-test.sh http://localhost:8080 10 60 50

# Using hey (if installed)
hey -z 60s -c 10 -q 50 http://localhost:8080/api/tasks

# Using Apache Bench
ab -n 1000 -c 10 http://localhost:8080/api/tasks
```

## 🔒 Security Best Practices

### Container Security
- Run as non-root user
- Use minimal base images (Alpine)
- Scan images for vulnerabilities
- Use read-only root filesystem
- Drop unnecessary capabilities

### Kubernetes Security
- Use namespaces for isolation
- Implement RBAC (Role-Based Access Control)
- Use Network Policies
- Secure secrets management
- Regular security updates

## 🚀 Production Considerations

### High Availability
- Multiple replicas across availability zones
- Pod Disruption Budgets
- Resource quotas and limits
- Monitoring and alerting

### Performance
- Resource optimization
- Horizontal Pod Autoscaler
- Vertical Pod Autoscaler
- Database connection pooling

### Observability
- Structured logging
- Metrics collection (Prometheus)
- Distributed tracing
- Health monitoring

## 📝 Next Steps

1. **Add Authentication**: Implement JWT-based auth
2. **Database Migration**: Add schema migration system
3. **Caching**: Implement Redis for caching
4. **Message Queue**: Add background job processing
5. **Monitoring**: Set up Prometheus and Grafana
6. **CI/CD**: Implement automated deployment pipeline
7. **Multi-environment**: Set up staging/production environments

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Happy Learning! 🎉**

This project demonstrates real-world Docker and Kubernetes patterns. Experiment with different configurations, break things, and learn from the experience!
