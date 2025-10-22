#!/bin/bash

# Kubernetes deployment script
# This script automates the deployment process with proper error handling

set -e  # Exit on any error

# Configuration
NAMESPACE="taskmanager"
IMAGE_TAG=${1:-"latest"}
WAIT_TIMEOUT=${2:-300}

echo "🚀 Deploying Task Management API to Kubernetes"
echo "Namespace: $NAMESPACE"
echo "Image Tag: $IMAGE_TAG"
echo ""

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl is not installed or not in PATH"
        echo "   Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check if we can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ Cannot connect to Kubernetes cluster"
        echo "   Please check your kubeconfig and cluster status"
        exit 1
    fi
    
    echo "✅ kubectl is available and connected to cluster"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        echo "✅ Namespace '$NAMESPACE' already exists"
    else
        echo "📁 Creating namespace '$NAMESPACE'..."
        kubectl apply -f k8s/namespace.yaml
        echo "✅ Namespace created"
    fi
}

# Function to apply configuration
apply_config() {
    echo "⚙️  Applying configuration..."
    
    # Apply ConfigMaps and Secrets first
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/secret.yaml
    echo "✅ Configuration applied"
}

# Function to deploy storage
deploy_storage() {
    echo "💾 Deploying storage..."
    kubectl apply -f k8s/postgres-pvc.yaml
    
    # Wait for PVC to be bound
    echo "⏳ Waiting for PVC to be bound..."
    kubectl wait --for=condition=Bound pvc/postgres-pvc -n $NAMESPACE --timeout=${WAIT_TIMEOUT}s
    echo "✅ Storage deployed"
}

# Function to deploy database
deploy_database() {
    echo "🗄️  Deploying PostgreSQL database..."
    kubectl apply -f k8s/postgres-deployment.yaml
    kubectl apply -f k8s/postgres-service.yaml
    
    # Wait for database to be ready
    echo "⏳ Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=${WAIT_TIMEOUT}s
    echo "✅ Database deployed and ready"
}

# Function to deploy API
deploy_api() {
    echo "🌐 Deploying API..."
    
    # Update image tag if specified
    if [ "$IMAGE_TAG" != "latest" ]; then
        echo "📝 Updating image tag to: $IMAGE_TAG"
        kubectl patch deployment taskmanager-api-deployment -n $NAMESPACE -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"api\",\"image\":\"taskmanager-api:$IMAGE_TAG\"}]}}}}"
    else
        kubectl apply -f k8s/api-deployment.yaml
    fi
    
    kubectl apply -f k8s/api-service.yaml
    
    # Wait for API to be ready
    echo "⏳ Waiting for API to be ready..."
    kubectl wait --for=condition=ready pod -l app=task-management-api -n $NAMESPACE --timeout=${WAIT_TIMEOUT}s
    echo "✅ API deployed and ready"
}

# Function to deploy scaling configuration
deploy_scaling() {
    echo "📈 Deploying scaling configuration..."
    kubectl apply -f k8s/hpa.yaml
    kubectl apply -f k8s/pod-disruption-budget.yaml
    echo "✅ Scaling configuration deployed"
}

# Function to deploy ingress (optional)
deploy_ingress() {
    if [ -f "k8s/ingress.yaml" ]; then
        echo "🌍 Deploying ingress..."
        kubectl apply -f k8s/ingress.yaml
        echo "✅ Ingress deployed"
    else
        echo "⚠️  Ingress configuration not found, skipping..."
    fi
}

# Function to show deployment status
show_status() {
    echo ""
    echo "📊 Deployment Status:"
    echo "===================="
    
    echo ""
    echo "Pods:"
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "Services:"
    kubectl get svc -n $NAMESPACE
    
    echo ""
    echo "HPA Status:"
    kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "HPA not available"
    
    echo ""
    echo "Ingress:"
    kubectl get ingress -n $NAMESPACE 2>/dev/null || echo "No ingress configured"
}

# Function to test deployment
test_deployment() {
    echo ""
    echo "🧪 Testing deployment..."
    
    # Get service endpoint
    SERVICE_NAME="taskmanager-api-service"
    
    # Try to get external IP (for LoadBalancer)
    EXTERNAL_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$EXTERNAL_IP" ]; then
        API_URL="http://$EXTERNAL_IP"
        echo "🌐 Testing external endpoint: $API_URL"
        
        if curl -s "$API_URL/api/health" > /dev/null; then
            echo "✅ External endpoint is accessible"
        else
            echo "⚠️  External endpoint not yet accessible (may take a few minutes)"
        fi
    else
        echo "🔧 No external IP found, use port-forward for testing:"
        echo "   kubectl port-forward svc/$SERVICE_NAME 8080:80 -n $NAMESPACE"
        echo "   curl http://localhost:8080/api/health"
    fi
}

# Function to show useful commands
show_commands() {
    echo ""
    echo "💡 Useful Commands:"
    echo "=================="
    echo ""
    echo "# View logs:"
    echo "kubectl logs -f deployment/taskmanager-api-deployment -n $NAMESPACE"
    echo ""
    echo "# Port forward for local access:"
    echo "kubectl port-forward svc/taskmanager-api-service 8080:80 -n $NAMESPACE"
    echo ""
    echo "# Scale manually:"
    echo "kubectl scale deployment taskmanager-api-deployment --replicas=5 -n $NAMESPACE"
    echo ""
    echo "# Update image:"
    echo "kubectl set image deployment/taskmanager-api-deployment api=taskmanager-api:v2.0.0 -n $NAMESPACE"
    echo ""
    echo "# Check HPA status:"
    echo "kubectl get hpa -n $NAMESPACE"
    echo ""
    echo "# Run load test:"
    echo "./scripts/load-test.sh http://localhost:8080 10 60 50"
}

# Main execution
main() {
    echo "🏁 Starting deployment process..."
    
    check_kubectl
    create_namespace
    apply_config
    deploy_storage
    deploy_database
    deploy_api
    deploy_scaling
    deploy_ingress
    
    show_status
    test_deployment
    show_commands
    
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo ""
    echo "🚀 Your Task Management API is now running on Kubernetes!"
}

# Run main function
main
