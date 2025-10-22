#!/bin/bash

# Cleanup script for removing all deployed resources
# Use this to clean up your Kubernetes cluster

set -e

NAMESPACE="taskmanager"
FORCE=${1:-false}

echo "🧹 Kubernetes Cleanup Script"
echo "Namespace: $NAMESPACE"
echo ""

# Function to confirm deletion
confirm_deletion() {
    if [ "$FORCE" != "true" ]; then
        echo "⚠️  This will delete ALL resources in the '$NAMESPACE' namespace!"
        echo "   This includes:"
        echo "   - All pods and deployments"
        echo "   - All services and ingress"
        echo "   - All persistent volumes and data"
        echo "   - ConfigMaps and secrets"
        echo ""
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Cleanup cancelled"
            exit 1
        fi
    fi
}

# Function to delete resources in order
cleanup_resources() {
    echo "🗑️  Deleting Kubernetes resources..."
    
    # Delete HPA first to prevent scaling during cleanup
    echo "📉 Deleting HPA..."
    kubectl delete hpa --all -n $NAMESPACE --ignore-not-found=true
    
    # Delete ingress
    echo "🌍 Deleting ingress..."
    kubectl delete ingress --all -n $NAMESPACE --ignore-not-found=true
    
    # Delete services
    echo "🌐 Deleting services..."
    kubectl delete svc --all -n $NAMESPACE --ignore-not-found=true
    
    # Delete deployments
    echo "🚀 Deleting deployments..."
    kubectl delete deployment --all -n $NAMESPACE --ignore-not-found=true
    
    # Wait for pods to terminate
    echo "⏳ Waiting for pods to terminate..."
    kubectl wait --for=delete pod --all -n $NAMESPACE --timeout=60s || true
    
    # Delete PVCs (this will delete data!)
    echo "💾 Deleting persistent volume claims..."
    kubectl delete pvc --all -n $NAMESPACE --ignore-not-found=true
    
    # Delete ConfigMaps and Secrets
    echo "⚙️  Deleting configuration..."
    kubectl delete configmap --all -n $NAMESPACE --ignore-not-found=true
    kubectl delete secret --all -n $NAMESPACE --ignore-not-found=true
    
    # Delete Pod Disruption Budgets
    echo "🛡️  Deleting pod disruption budgets..."
    kubectl delete pdb --all -n $NAMESPACE --ignore-not-found=true
    
    echo "✅ All resources deleted"
}

# Function to delete namespace
delete_namespace() {
    echo "📁 Deleting namespace..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    # Wait for namespace to be fully deleted
    echo "⏳ Waiting for namespace to be deleted..."
    while kubectl get namespace $NAMESPACE &> /dev/null; do
        echo "   Still deleting namespace..."
        sleep 5
    done
    
    echo "✅ Namespace deleted"
}

# Function to cleanup Docker resources (optional)
cleanup_docker() {
    echo ""
    read -p "🐳 Do you want to cleanup Docker resources too? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🧹 Cleaning up Docker resources..."
        
        # Stop and remove containers
        if docker-compose ps -q &> /dev/null; then
            echo "🛑 Stopping Docker Compose services..."
            docker-compose down -v --remove-orphans
        fi
        
        # Remove images
        echo "🗑️  Removing Docker images..."
        docker rmi taskmanager-api:latest 2>/dev/null || true
        docker rmi $(docker images -q --filter "reference=taskmanager-api") 2>/dev/null || true
        
        # Clean up unused resources
        echo "🧽 Cleaning up unused Docker resources..."
        docker system prune -f
        
        echo "✅ Docker cleanup completed"
    fi
}

# Function to show final status
show_final_status() {
    echo ""
    echo "📊 Final Status:"
    echo "==============="
    
    # Check if namespace still exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        echo "⚠️  Namespace still exists (may be terminating)"
        kubectl get all -n $NAMESPACE 2>/dev/null || echo "No resources found"
    else
        echo "✅ Namespace completely removed"
    fi
    
    echo ""
    echo "🎉 Cleanup completed!"
    echo ""
    echo "💡 To redeploy:"
    echo "   ./scripts/deploy.sh"
}

# Main execution
main() {
    # Check if namespace exists
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        echo "ℹ️  Namespace '$NAMESPACE' does not exist"
        echo "✅ Nothing to clean up"
        exit 0
    fi
    
    confirm_deletion
    cleanup_resources
    delete_namespace
    cleanup_docker
    show_final_status
}

# Handle script arguments
case "${1:-}" in
    --force|-f)
        FORCE=true
        main
        ;;
    --help|-h)
        echo "Usage: $0 [--force|-f] [--help|-h]"
        echo ""
        echo "Options:"
        echo "  --force, -f    Skip confirmation prompts"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "This script will delete all resources in the '$NAMESPACE' namespace."
        echo "Use with caution as this will permanently delete all data!"
        ;;
    *)
        main
        ;;
esac
