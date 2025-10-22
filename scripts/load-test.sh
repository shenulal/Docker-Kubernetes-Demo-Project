#!/bin/bash

# Load testing script to demonstrate HPA scaling
# This script generates load to trigger horizontal pod autoscaling

set -e

# Configuration
API_URL=${1:-"http://localhost:3000"}
CONCURRENT_USERS=${2:-10}
DURATION=${3:-300}  # 5 minutes
REQUESTS_PER_SECOND=${4:-50}

echo "🚀 Starting load test for HPA demonstration"
echo "API URL: $API_URL"
echo "Concurrent Users: $CONCURRENT_USERS"
echo "Duration: ${DURATION}s"
echo "Requests per second: $REQUESTS_PER_SECOND"
echo ""

# Check if required tools are installed
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        echo "   For $1: $2"
        exit 1
    fi
}

check_tool "curl" "curl is usually pre-installed"
check_tool "kubectl" "https://kubernetes.io/docs/tasks/tools/"

# Optional: Check for advanced load testing tools
if command -v hey &> /dev/null; then
    LOAD_TOOL="hey"
    echo "✅ Using 'hey' for load testing"
elif command -v ab &> /dev/null; then
    LOAD_TOOL="ab"
    echo "✅ Using 'ab' (Apache Bench) for load testing"
else
    LOAD_TOOL="curl"
    echo "⚠️  Using basic curl for load testing (install 'hey' or 'ab' for better results)"
fi

# Function to monitor HPA status
monitor_hpa() {
    echo "📊 Monitoring HPA status..."
    kubectl get hpa taskmanager-api-hpa -n taskmanager --watch &
    HPA_PID=$!
}

# Function to monitor pod status
monitor_pods() {
    echo "📦 Monitoring pod status..."
    kubectl get pods -n taskmanager -l app=task-management-api --watch &
    PODS_PID=$!
}

# Function to create sample tasks for testing
create_sample_tasks() {
    echo "📝 Creating sample tasks..."
    for i in {1..10}; do
        curl -s -X POST "$API_URL/api/tasks" \
            -H "Content-Type: application/json" \
            -d "{
                \"title\": \"Load Test Task $i\",
                \"description\": \"Task created for load testing\",
                \"priority\": \"medium\"
            }" > /dev/null
    done
    echo "✅ Sample tasks created"
}

# Function to run load test with different tools
run_load_test() {
    case $LOAD_TOOL in
        "hey")
            echo "🔥 Running load test with hey..."
            hey -z ${DURATION}s -c $CONCURRENT_USERS -q $REQUESTS_PER_SECOND "$API_URL/api/tasks"
            ;;
        "ab")
            echo "🔥 Running load test with Apache Bench..."
            TOTAL_REQUESTS=$((REQUESTS_PER_SECOND * DURATION))
            ab -n $TOTAL_REQUESTS -c $CONCURRENT_USERS "$API_URL/api/tasks"
            ;;
        "curl")
            echo "🔥 Running basic load test with curl..."
            run_curl_load_test
            ;;
    esac
}

# Basic curl-based load test
run_curl_load_test() {
    local end_time=$(($(date +%s) + DURATION))
    local request_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        for i in $(seq 1 $CONCURRENT_USERS); do
            curl -s "$API_URL/api/tasks" > /dev/null &
            ((request_count++))
            
            # Rate limiting
            if [ $((request_count % REQUESTS_PER_SECOND)) -eq 0 ]; then
                sleep 1
            fi
        done
        wait
    done
    
    echo "✅ Completed $request_count requests"
}

# Cleanup function
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    if [ ! -z "$HPA_PID" ]; then
        kill $HPA_PID 2>/dev/null || true
    fi
    if [ ! -z "$PODS_PID" ]; then
        kill $PODS_PID 2>/dev/null || true
    fi
    
    # Kill any background curl processes
    pkill -f "curl.*$API_URL" 2>/dev/null || true
    
    echo "✅ Cleanup completed"
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Main execution
echo "🏁 Starting load test sequence..."

# Check if API is accessible
if ! curl -s "$API_URL/api/health" > /dev/null; then
    echo "❌ API is not accessible at $API_URL"
    echo "   Make sure the API is running and accessible"
    exit 1
fi

echo "✅ API is accessible"

# Create sample data
create_sample_tasks

# Start monitoring
monitor_hpa
monitor_pods

echo ""
echo "⏱️  Waiting 10 seconds for monitoring to start..."
sleep 10

# Run the load test
run_load_test

echo ""
echo "⏱️  Load test completed. Waiting 60 seconds to observe scale-down..."
sleep 60

echo ""
echo "📈 Final HPA status:"
kubectl get hpa taskmanager-api-hpa -n taskmanager

echo ""
echo "📦 Final pod status:"
kubectl get pods -n taskmanager -l app=task-management-api

echo ""
echo "🎉 Load test demonstration completed!"
echo ""
echo "💡 Tips:"
echo "   - Watch the HPA scale up pods when CPU/memory usage increases"
echo "   - Observe the scale-down behavior after load decreases"
echo "   - Check pod resource usage: kubectl top pods -n taskmanager"
echo "   - View HPA events: kubectl describe hpa taskmanager-api-hpa -n taskmanager"
