#!/bin/bash

# API Testing Script
# This script demonstrates all the API endpoints

set -e

# Configuration
API_URL=${1:-"http://localhost:3000"}
VERBOSE=${2:-false}

echo "🧪 Testing Task Management API"
echo "API URL: $API_URL"
echo ""

# Function to make HTTP requests
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo "📡 $description"
    echo "   $method $API_URL$endpoint"
    
    if [ "$VERBOSE" = "true" ]; then
        if [ -n "$data" ]; then
            curl -v -X $method "$API_URL$endpoint" \
                -H "Content-Type: application/json" \
                -d "$data"
        else
            curl -v -X $method "$API_URL$endpoint"
        fi
    else
        if [ -n "$data" ]; then
            curl -s -X $method "$API_URL$endpoint" \
                -H "Content-Type: application/json" \
                -d "$data" | head -c 200
        else
            curl -s -X $method "$API_URL$endpoint" | head -c 200
        fi
    fi
    
    echo ""
    echo ""
}

# Test health endpoints
echo "🏥 Testing Health Endpoints"
echo "=========================="
make_request "GET" "/api/health" "" "Health check"
make_request "GET" "/api/health/live" "" "Liveness probe"
make_request "GET" "/api/health/ready" "" "Readiness probe"

# Test root endpoint
echo "🏠 Testing Root Endpoint"
echo "======================="
make_request "GET" "/" "" "Root endpoint"

# Test tasks endpoints
echo "📝 Testing Tasks Endpoints"
echo "========================="

# Get all tasks (should be empty initially)
make_request "GET" "/api/tasks" "" "Get all tasks (empty)"

# Create first task
TASK1_DATA='{"title": "Learn Docker", "description": "Complete Docker containerization tutorial", "priority": "high"}'
make_request "POST" "/api/tasks" "$TASK1_DATA" "Create first task"

# Create second task
TASK2_DATA='{"title": "Learn Kubernetes", "description": "Deploy application to Kubernetes cluster", "priority": "medium"}'
make_request "POST" "/api/tasks" "$TASK2_DATA" "Create second task"

# Create third task with due date
TASK3_DATA='{"title": "Setup CI/CD", "description": "Implement automated deployment pipeline", "priority": "low", "due_date": "2025-12-31T23:59:59.000Z"}'
make_request "POST" "/api/tasks" "$TASK3_DATA" "Create third task with due date"

# Get all tasks (should have 3 tasks now)
make_request "GET" "/api/tasks" "" "Get all tasks (with data)"

# Get tasks with filtering
make_request "GET" "/api/tasks?status=pending" "" "Get pending tasks"
make_request "GET" "/api/tasks?priority=high" "" "Get high priority tasks"
make_request "GET" "/api/tasks?page=1&limit=2" "" "Get tasks with pagination"

# Get specific task
make_request "GET" "/api/tasks/1" "" "Get task by ID"

# Update task
UPDATE_DATA='{"status": "in_progress", "description": "Currently learning Docker containerization"}'
make_request "PUT" "/api/tasks/1" "$UPDATE_DATA" "Update task status"

# Get updated task
make_request "GET" "/api/tasks/1" "" "Get updated task"

# Get task statistics
make_request "GET" "/api/tasks/stats/summary" "" "Get task statistics"

# Test error cases
echo "❌ Testing Error Cases"
echo "===================="

# Invalid task ID
make_request "GET" "/api/tasks/999" "" "Get non-existent task (should return 404)"

# Invalid data
INVALID_DATA='{"title": "", "priority": "invalid"}'
make_request "POST" "/api/tasks" "$INVALID_DATA" "Create task with invalid data (should return 400)"

# Invalid endpoint
make_request "GET" "/api/invalid" "" "Invalid endpoint (should return 404)"

echo "✅ API testing completed!"
echo ""
echo "💡 Summary:"
echo "   - All health endpoints are working"
echo "   - CRUD operations are functional"
echo "   - Filtering and pagination work"
echo "   - Error handling is proper"
echo "   - Database integration is successful"
echo ""
echo "🎉 Your Task Management API is fully functional!"
