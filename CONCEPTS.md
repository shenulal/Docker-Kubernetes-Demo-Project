# Docker & Kubernetes Concepts Explained

This document explains the key concepts demonstrated in this project with practical examples.

## 🐳 Docker Concepts

### 1. Containers vs Virtual Machines

**Virtual Machines:**
```
┌─────────────────────────────────────┐
│           Host Operating System      │
├─────────────────────────────────────┤
│              Hypervisor             │
├─────────────┬─────────────┬─────────┤
│   Guest OS  │   Guest OS  │ Guest OS│
│   ┌─────┐   │   ┌─────┐   │ ┌─────┐ │
│   │ App │   │   │ App │   │ │ App │ │
│   └─────┘   │   └─────┘   │ └─────┘ │
└─────────────┴─────────────┴─────────┘
```

**Containers:**
```
┌─────────────────────────────────────┐
│           Host Operating System      │
├─────────────────────────────────────┤
│            Docker Engine            │
├─────────────┬─────────────┬─────────┤
│ Container 1 │ Container 2 │Container│
│   ┌─────┐   │   ┌─────┐   │ ┌─────┐ │
│   │ App │   │   │ App │   │ │ App │ │
│   └─────┘   │   └─────┘   │ └─────┘ │
└─────────────┴─────────────┴─────────┘
```

**Key Differences:**
- **Containers** share the host OS kernel (lightweight)
- **VMs** include full guest OS (heavyweight)
- **Containers** start in seconds, **VMs** in minutes
- **Containers** use less resources than **VMs**

### 2. Docker Images and Layers

Docker images are built in layers, each representing a filesystem change:

```dockerfile
FROM node:18-alpine          # Base layer
WORKDIR /app                 # Layer 2: Create directory
COPY package*.json ./        # Layer 3: Copy package files
RUN npm ci                   # Layer 4: Install dependencies
COPY src/ ./src/            # Layer 5: Copy source code
CMD ["node", "src/server.js"] # Layer 6: Set default command
```

**Layer Benefits:**
- **Caching**: Unchanged layers are reused
- **Sharing**: Multiple images can share layers
- **Efficiency**: Only changed layers need to be downloaded

### 3. Multi-stage Builds

Our Dockerfile uses multi-stage builds for optimization:

```dockerfile
# Stage 1: Builder (includes dev dependencies)
FROM node:18-alpine AS builder
COPY package*.json ./
RUN npm ci  # Install ALL dependencies

# Stage 2: Production (minimal)
FROM node:18-alpine AS production
COPY package*.json ./
RUN npm ci --only=production  # Only production deps
COPY --from=builder /app/src ./src  # Copy from builder stage
```

**Benefits:**
- Smaller final image size
- Separation of build and runtime environments
- Better security (no build tools in production)

### 4. Docker Compose

Docker Compose orchestrates multiple containers:

```yaml
services:
  api:
    build: .
    depends_on:
      - postgres
    environment:
      - DB_HOST=postgres  # Service name as hostname
  
  postgres:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

**Key Features:**
- **Service Discovery**: Services can reach each other by name
- **Dependency Management**: Control startup order
- **Volume Management**: Persist data between container restarts
- **Network Isolation**: Services communicate on private network

## ☸️ Kubernetes Concepts

### 1. Container → Pod → Deployment → Service

```
Container: Single process
    ↓
Pod: One or more containers sharing network/storage
    ↓
Deployment: Manages multiple pod replicas
    ↓
Service: Stable network endpoint for pods
```

**Example Flow:**
1. **Container**: Node.js app process
2. **Pod**: Container + shared volumes + network
3. **Deployment**: 3 replicas of the pod
4. **Service**: Load balancer distributing traffic to 3 pods

### 2. Kubernetes Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Control Plane                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│
│  │ API Server  │ │   etcd      │ │    Scheduler        ││
│  └─────────────┘ └─────────────┘ └─────────────────────┘│
│  ┌─────────────┐ ┌─────────────────────────────────────┐│
│  │Controller   │ │       Cloud Controller             ││
│  │Manager      │ │       Manager                      ││
│  └─────────────┘ └─────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼──────┐    ┌─────────▼──────┐    ┌─────────▼──────┐
│   Worker      │    │   Worker       │    │   Worker       │
│   Node 1      │    │   Node 2       │    │   Node 3       │
│ ┌───────────┐ │    │ ┌───────────┐  │    │ ┌───────────┐  │
│ │  kubelet  │ │    │ │  kubelet  │  │    │ │  kubelet  │  │
│ │  kube-    │ │    │ │  kube-    │  │    │ │  kube-    │  │
│ │  proxy    │ │    │ │  proxy    │  │    │ │  proxy    │  │
│ │  Container│ │    │ │  Container│  │    │ │  Container│  │
│ │  Runtime  │ │    │ │  Runtime  │  │    │ │  Runtime  │  │
│ └───────────┘ │    │ └───────────┘  │    │ └───────────┘  │
│   Pods        │    │   Pods         │    │   Pods         │
└───────────────┘    └────────────────┘    └────────────────┘
```

### 3. Resource Hierarchy

```
Cluster
└── Namespace (taskmanager)
    ├── ConfigMap (taskmanager-config)
    ├── Secret (taskmanager-secrets)
    ├── PersistentVolumeClaim (postgres-pvc)
    ├── Deployment (taskmanager-api-deployment)
    │   └── ReplicaSet
    │       ├── Pod (api-xxx-1)
    │       ├── Pod (api-xxx-2)
    │       └── Pod (api-xxx-3)
    ├── Service (taskmanager-api-service)
    ├── Ingress (taskmanager-api-ingress)
    └── HorizontalPodAutoscaler (taskmanager-api-hpa)
```

### 4. Service Types Explained

#### ClusterIP (Default)
```
┌─────────────────────────────────────┐
│              Cluster                │
│  ┌─────────────────────────────────┐│
│  │         Service                 ││
│  │      (ClusterIP)                ││
│  │    10.96.100.200:80            ││
│  └─────────────┬───────────────────┘│
│                │                    │
│    ┌───────────▼───┐ ┌─────────────┐│
│    │   Pod 1       │ │   Pod 2     ││
│    │ 10.244.1.10   │ │ 10.244.2.15 ││
│    └───────────────┘ └─────────────┘│
└─────────────────────────────────────┘
```
- **Internal only**: Only accessible within cluster
- **Use case**: Database, internal APIs

#### NodePort
```
┌─────────────────────────────────────┐
│              Cluster                │
│  ┌─────────────────────────────────┐│
│  │         Service                 ││
│  │       (NodePort)                ││
│  │    10.96.100.200:80            ││
│  └─────────────┬───────────────────┘│
│                │                    │
│    ┌───────────▼───┐ ┌─────────────┐│
│    │   Pod 1       │ │   Pod 2     ││
│    └───────────────┘ └─────────────┘│
└─────────────────────────────────────┘
              │
    ┌─────────▼─────────┐
    │   External        │
    │   Access          │
    │ NodeIP:30080      │
    └───────────────────┘
```
- **External access**: Via any node's IP + port (30000-32767)
- **Use case**: Development, small deployments

#### LoadBalancer
```
┌─────────────────────────────────────┐
│         Cloud Provider              │
│  ┌─────────────────────────────────┐│
│  │      Load Balancer              ││
│  │    (External IP)                ││
│  └─────────────┬───────────────────┘│
└────────────────┼────────────────────┘
                 │
┌────────────────▼────────────────────┐
│              Cluster                │
│  ┌─────────────────────────────────┐│
│  │         Service                 ││
│  │     (LoadBalancer)              ││
│  └─────────────┬───────────────────┘│
│                │                    │
│    ┌───────────▼───┐ ┌─────────────┐│
│    │   Pod 1       │ │   Pod 2     ││
│    └───────────────┘ └─────────────┘│
└─────────────────────────────────────┘
```
- **Cloud integration**: Creates external load balancer
- **Use case**: Production web applications

### 5. ConfigMaps vs Secrets

#### ConfigMap (Non-sensitive data)
```yaml
apiVersion: v1
kind: ConfigMap
data:
  DATABASE_HOST: "postgres-service"
  DATABASE_PORT: "5432"
  LOG_LEVEL: "info"
```

#### Secret (Sensitive data)
```yaml
apiVersion: v1
kind: Secret
data:
  DATABASE_PASSWORD: "c2VjcmV0cGFzc3dvcmQ="  # base64 encoded
```

**Key Differences:**
- **ConfigMap**: Plain text, visible to anyone with access
- **Secret**: Base64 encoded, additional access controls
- **Both**: Can be mounted as files or environment variables

### 6. Persistent Volumes

```
┌─────────────────────────────────────┐
│         Storage System              │
│    (AWS EBS, GCP Disk, etc.)       │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│      Persistent Volume (PV)         │
│         (Cluster Resource)          │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│  Persistent Volume Claim (PVC)      │
│      (Namespace Resource)           │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│            Pod                      │
│    (Mounts PVC as Volume)          │
└─────────────────────────────────────┘
```

**Lifecycle:**
1. **PV**: Admin creates storage resource
2. **PVC**: User requests storage
3. **Binding**: Kubernetes matches PVC to PV
4. **Mount**: Pod uses PVC as volume

### 7. Health Checks (Probes)

#### Liveness Probe
```yaml
livenessProbe:
  httpGet:
    path: /api/health/live
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
```
- **Purpose**: Is the container alive?
- **Action**: Restart container if fails
- **Example**: Deadlock detection

#### Readiness Probe
```yaml
readinessProbe:
  httpGet:
    path: /api/health/ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```
- **Purpose**: Is the container ready for traffic?
- **Action**: Remove from service endpoints if fails
- **Example**: Database connection check

#### Startup Probe
```yaml
startupProbe:
  httpGet:
    path: /api/health/live
    port: 3000
  failureThreshold: 10
  periodSeconds: 5
```
- **Purpose**: Has the container started successfully?
- **Action**: Gives more time for slow-starting containers
- **Example**: Application initialization

### 8. Horizontal Pod Autoscaler (HPA)

```
┌─────────────────────────────────────┐
│              HPA                    │
│  ┌─────────────────────────────────┐│
│  │  Target: 70% CPU                ││
│  │  Min Replicas: 2                ││
│  │  Max Replicas: 10               ││
│  └─────────────┬───────────────────┘│
└────────────────┼────────────────────┘
                 │
    ┌────────────▼────────────┐
    │      Deployment         │
    │                         │
    │  Current: 3 replicas    │
    │  CPU Usage: 85%         │
    └────────────┬────────────┘
                 │
    ┌────────────▼────────────┐
    │     Scale Up to 4       │
    │    (CPU > 70%)          │
    └─────────────────────────┘
```

**Scaling Logic:**
1. **Metrics Collection**: HPA reads CPU/memory metrics
2. **Decision**: Compare current vs target utilization
3. **Action**: Scale up/down within min/max bounds
4. **Cooldown**: Wait before next scaling decision

### 9. Rolling Updates

```
Initial State (v1):
┌─────┐ ┌─────┐ ┌─────┐
│ v1  │ │ v1  │ │ v1  │
└─────┘ └─────┘ └─────┘

Step 1: Create new pod (v2):
┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
│ v1  │ │ v1  │ │ v1  │ │ v2  │
└─────┘ └─────┘ └─────┘ └─────┘

Step 2: Remove old pod:
┌─────┐ ┌─────┐ ┌─────┐
│ v1  │ │ v1  │ │ v2  │
└─────┘ └─────┘ └─────┘

Step 3: Continue until all updated:
┌─────┐ ┌─────┐ ┌─────┐
│ v2  │ │ v2  │ │ v2  │
└─────┘ └─────┘ └─────┘
```

**Benefits:**
- **Zero downtime**: Always have running pods
- **Gradual rollout**: Detect issues early
- **Rollback capability**: Easy to revert if problems occur

## 🔄 When to Use Docker Compose vs Kubernetes

### Docker Compose
**Use when:**
- Local development
- Simple multi-container applications
- Single-host deployments
- Learning containerization
- CI/CD testing

**Example scenarios:**
- Development environment setup
- Integration testing
- Small applications with 2-5 services

### Kubernetes
**Use when:**
- Production deployments
- Multi-host/cloud deployments
- Need auto-scaling
- High availability requirements
- Complex service mesh

**Example scenarios:**
- Production web applications
- Microservices architecture
- Applications requiring 99.9% uptime
- Multi-environment deployments (dev/staging/prod)

## 🎯 Best Practices Summary

### Docker
1. **Use multi-stage builds** for smaller images
2. **Run as non-root user** for security
3. **Use specific image tags** (not `latest`)
4. **Minimize layers** by combining RUN commands
5. **Use .dockerignore** to exclude unnecessary files

### Kubernetes
1. **Set resource requests/limits** for all containers
2. **Use health checks** (liveness, readiness, startup)
3. **Implement proper logging** and monitoring
4. **Use namespaces** for resource isolation
5. **Apply security contexts** and pod security policies
6. **Use ConfigMaps/Secrets** for configuration
7. **Implement proper backup strategies** for persistent data

This foundation will help you understand the practical implementations in this project!
