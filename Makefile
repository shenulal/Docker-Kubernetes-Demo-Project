# Makefile for Docker & Kubernetes Learning Project
# This provides convenient commands for common operations

.PHONY: help install build up down logs test deploy clean status scale load-test

# Default target
help: ## Show this help message
	@echo "Docker & Kubernetes Learning Project"
	@echo "====================================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Variables
IMAGE_NAME := taskmanager-api
IMAGE_TAG := latest
NAMESPACE := taskmanager
KUBECONFIG ?= ~/.kube/config

# Development commands
install: ## Install Node.js dependencies
	npm install

build: ## Build Docker image
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "✅ Image built: $(IMAGE_NAME):$(IMAGE_TAG)"

build-prod: ## Build production Docker image with optimizations
	./scripts/docker-build.sh $(IMAGE_TAG)

# Docker Compose commands
up: ## Start services with Docker Compose
	docker-compose up -d
	@echo "✅ Services started. API available at http://localhost:3000"

up-dev: ## Start services in development mode
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

down: ## Stop Docker Compose services
	docker-compose down

down-volumes: ## Stop services and remove volumes (⚠️  deletes data)
	docker-compose down -v

logs: ## Show Docker Compose logs
	docker-compose logs -f

logs-api: ## Show API logs only
	docker-compose logs -f api

# Testing commands
test: ## Run tests locally
	npm test

test-api: ## Test API endpoints (requires running service)
	@echo "Testing API endpoints..."
	@curl -s http://localhost:3000/api/health || echo "❌ API not accessible"
	@curl -s http://localhost:3000/api/tasks || echo "❌ Tasks endpoint not accessible"

# Kubernetes commands
k8s-check: ## Check Kubernetes cluster connection
	@kubectl cluster-info
	@kubectl get nodes

deploy: ## Deploy to Kubernetes
	@echo "🚀 Deploying to Kubernetes..."
	chmod +x scripts/deploy.sh
	./scripts/deploy.sh $(IMAGE_TAG)

deploy-dev: ## Deploy to Kubernetes with development settings
	kubectl apply -f k8s/
	@echo "✅ Deployed to Kubernetes namespace: $(NAMESPACE)"

clean: ## Clean up Kubernetes resources
	@echo "🧹 Cleaning up Kubernetes resources..."
	chmod +x scripts/cleanup.sh
	./scripts/cleanup.sh

clean-force: ## Force clean up without confirmation
	chmod +x scripts/cleanup.sh
	./scripts/cleanup.sh --force

# Monitoring commands
status: ## Show Kubernetes deployment status
	@echo "📊 Kubernetes Status:"
	@echo "===================="
	kubectl get all -n $(NAMESPACE)
	@echo ""
	@echo "HPA Status:"
	kubectl get hpa -n $(NAMESPACE) || echo "No HPA found"

pods: ## Show pod status and logs
	kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "Recent pod events:"
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -10

logs-k8s: ## Show Kubernetes API logs
	kubectl logs -f deployment/taskmanager-api-deployment -n $(NAMESPACE)

describe: ## Describe main resources
	@echo "🔍 Describing main resources..."
	kubectl describe deployment taskmanager-api-deployment -n $(NAMESPACE)
	kubectl describe service taskmanager-api-service -n $(NAMESPACE)
	kubectl describe hpa taskmanager-api-hpa -n $(NAMESPACE) || echo "No HPA found"

# Scaling commands
scale: ## Scale API deployment (usage: make scale REPLICAS=5)
	kubectl scale deployment taskmanager-api-deployment --replicas=$(REPLICAS) -n $(NAMESPACE)
	@echo "✅ Scaled to $(REPLICAS) replicas"

scale-up: ## Scale up to 5 replicas
	$(MAKE) scale REPLICAS=5

scale-down: ## Scale down to 2 replicas
	$(MAKE) scale REPLICAS=2

# Load testing
load-test: ## Run load test to demonstrate HPA
	@echo "🔥 Running load test..."
	chmod +x scripts/load-test.sh
	./scripts/load-test.sh http://localhost:8080 10 60 50

load-test-heavy: ## Run heavy load test
	chmod +x scripts/load-test.sh
	./scripts/load-test.sh http://localhost:8080 20 300 100

# Port forwarding
port-forward: ## Port forward API service to localhost:8080
	@echo "🌐 Port forwarding API service to localhost:8080"
	@echo "   Access API at: http://localhost:8080"
	@echo "   Press Ctrl+C to stop"
	kubectl port-forward svc/taskmanager-api-service 8080:80 -n $(NAMESPACE)

port-forward-db: ## Port forward PostgreSQL to localhost:5432
	@echo "🗄️  Port forwarding PostgreSQL to localhost:5432"
	@echo "   Connect with: psql -h localhost -p 5432 -U postgres -d taskmanager"
	@echo "   For Docker Compose: psql -h localhost -p 5434 -U postgres -d taskmanager"
	@echo "   Press Ctrl+C to stop"
	kubectl port-forward svc/postgres-service 5432:5432 -n $(NAMESPACE)

# Utility commands
shell: ## Get shell access to API pod
	kubectl exec -it deployment/taskmanager-api-deployment -n $(NAMESPACE) -- /bin/sh

shell-db: ## Get shell access to PostgreSQL pod
	kubectl exec -it deployment/postgres-deployment -n $(NAMESPACE) -- /bin/bash

top: ## Show resource usage
	@echo "📈 Resource Usage:"
	kubectl top nodes || echo "Metrics server not available"
	kubectl top pods -n $(NAMESPACE) || echo "Metrics server not available"

events: ## Show recent cluster events
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

# Development helpers
dev-setup: ## Complete development setup
	$(MAKE) install
	$(MAKE) build
	$(MAKE) up
	@echo "✅ Development environment ready!"
	@echo "   API: http://localhost:3000"
	@echo "   pgAdmin: http://localhost:8080 (admin@example.com / admin)"

dev-reset: ## Reset development environment
	$(MAKE) down-volumes
	$(MAKE) build
	$(MAKE) up
	@echo "✅ Development environment reset!"

# Production helpers
prod-deploy: ## Complete production deployment
	$(MAKE) build-prod
	$(MAKE) deploy
	@echo "✅ Production deployment complete!"

prod-update: ## Update production deployment
	$(MAKE) build-prod IMAGE_TAG=v$(shell date +%Y%m%d-%H%M%S)
	kubectl set image deployment/taskmanager-api-deployment api=$(IMAGE_NAME):$(IMAGE_TAG) -n $(NAMESPACE)
	kubectl rollout status deployment/taskmanager-api-deployment -n $(NAMESPACE)
	@echo "✅ Production update complete!"

# Cleanup commands
docker-clean: ## Clean up Docker resources
	docker system prune -f
	docker volume prune -f

full-clean: ## Complete cleanup (Docker + Kubernetes)
	$(MAKE) clean-force
	$(MAKE) down-volumes
	$(MAKE) docker-clean
	@echo "✅ Complete cleanup finished!"

# Quick commands for common workflows
quick-start: dev-setup ## Quick start for development
quick-k8s: build deploy port-forward ## Quick Kubernetes deployment
quick-test: up test-api ## Quick test setup
