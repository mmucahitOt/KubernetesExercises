#!/bin/bash

# !!! IMPORTANT !!!
# the user should be logged in to Docker Hub before running this script
# docker login

# This script is used to deploy the todo_app application to a Kubernetes cluster.
# It is used to test the application in a Kubernetes environment.

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored headers
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

# Function to print colored info
print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Function to print colored success
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print colored warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print colored error
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Get the registry name and ports from the command line arguments
_DOCKER_REGISTRY=$1

# Export variables for substitution in manifest
export DOCKER_REGISTRY=$_DOCKER_REGISTRY
export TODO_APP_PORT=4000
export TODO_APP_BACKEND_PORT=4001
export RANDOM_IMAGE_PATH="/app/files/image.jpeg"
export VITE_TODO_API_URL="http://localhost:8081"
export VITE_TODO_BACKEND_API_URL="http://localhost:8081"

print_header "🚀 TODO APP DEPLOYMENT STARTING"
print_info "Docker Registry: $_DOCKER_REGISTRY"
print_info "Ports: TODO_APP=4000, TODO_APP_BACKEND=4001"

# Resolve directories relative to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
TODO_APP_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
ROOT_DIR="$(cd -- "${TODO_APP_ROOT}/.." >/dev/null 2>&1 && pwd -P)"
TODO_APP_DIR="${TODO_APP_ROOT}/todo_app"
TODO_APP_BACKEND_DIR="${TODO_APP_ROOT}/todo_app_backend"
FRONTEND_DIR="${TODO_APP_ROOT}/todo_app_frontend"
FRONTEND_DIST_DIR="${FRONTEND_DIR}/dist"
TODO_PUBLIC_DIR="${TODO_APP_DIR}/public"
TODO_APP_ROOT_MANIFESTS_DIR="${TODO_APP_ROOT}/manifests"
TODO_APP_MANIFESTS_DIR="${TODO_APP_DIR}/manifests"
TODO_APP_BACKEND_MANIFESTS_DIR="${TODO_APP_BACKEND_DIR}/manifests"

# Build frontend and move output to backend public
print_header "🎨 BUILDING FRONTEND"
print_info "Building frontend with Vite..."
if [ -d "${FRONTEND_DIR}" ]; then
  pushd "${FRONTEND_DIR}" >/dev/null
  if command -v npm >/dev/null 2>&1; then
    print_info "Installing dependencies..."
    npm ci || npm install
    print_success "Dependencies installed"
    
    print_info "Building frontend..."
    npm run build
    print_success "Frontend built successfully"
  else
    print_error "npm is not installed; cannot build frontend"
    exit 1
  fi
  popd >/dev/null

  print_info "Copying frontend dist to backend public..."
  mkdir -p "${TODO_PUBLIC_DIR}"
  rm -rf "${TODO_PUBLIC_DIR}/"*
  cp -R "${FRONTEND_DIST_DIR}/." "${TODO_PUBLIC_DIR}/"
  print_success "Frontend files copied to backend"
else
  print_warning "Frontend directory not found at ${FRONTEND_DIR}; skipping frontend build"
fi

# Build the Docker images (use absolute context)
print_header "🐳 BUILDING DOCKER IMAGES"
print_info "Building todo_app image..."
docker build -t todo_app:latest "${TODO_APP_DIR}"
print_success "todo_app image built"

print_info "Building todo_app_backend image..."
docker build -t todo_app_backend:latest "${TODO_APP_BACKEND_DIR}"
print_success "todo_app_backend image built"

# Tag the images for Docker Hub
print_header "🏷️  TAGGING IMAGES FOR DOCKER HUB"
docker tag todo_app:latest $_DOCKER_REGISTRY/todo_app:latest
docker tag todo_app_backend:latest $_DOCKER_REGISTRY/todo_app_backend:latest
print_success "All images tagged for Docker Hub"

# Push the Docker images to Docker Hub
print_header "📤 PUSHING IMAGES TO DOCKER HUB"
print_info "Pushing todo_app image..."
docker push $_DOCKER_REGISTRY/todo_app:latest
print_success "todo_app pushed"

print_info "Pushing todo_app_backend image..."
docker push $_DOCKER_REGISTRY/todo_app_backend:latest
print_success "todo_app_backend pushed"

EXISTING_CONTEXT=$(kubectl config get-contexts | grep "k3d-k3s-default")

print_header "☸️  KUBERNETES CLUSTER SETUP"
if [ -z "$EXISTING_CONTEXT" ]; then
  print_info "No existing cluster found, creating new one..."
  k3d cluster create -p 8081:80@loadbalancer --agents 2
  kubectl config use-context k3d-k3s-default
  print_success "Cluster created and context switched"
else
  print_info "Existing cluster found"
  kubectl config use-context k3d-k3s-default
  print_success "Context switched to existing cluster"
fi

print_info "Cluster information:"
kubectl cluster-info

print_info "Starting cluster..."
k3d cluster start
print_success "Cluster started successfully"

# Create the directory for persistent storage
print_header "💾 SETTING UP PERSISTENT STORAGE"
print_info "Creating storage directory on node..."
docker exec k3d-k3s-default-agent-0 mkdir -p /tmp/kube
print_success "Storage directory created"

print_header "📁 NAMESPACE SETUP"
print_info "Creating namespace..."
kubectl create -f "${TODO_APP_ROOT_MANIFESTS_DIR}/namespace.yaml"
print_success "Namespace created"

print_info "Creating ConfigMap..."
envsubst < "${TODO_APP_ROOT_MANIFESTS_DIR}/config_map.yaml" | kubectl apply -f -
print_success "ConfigMap created"

print_info "Activating namespace..."
kubens project
print_success "Namespace activated"

print_header "📋 APPLYING KUBERNETES MANIFESTS"
print_info "Applying Deployment..."
envsubst < "${TODO_APP_ROOT_MANIFESTS_DIR}/deployment.yaml" | kubectl apply -f -
print_success "Deployment applied"

print_info "Applying Persistent Volumes..."
kubectl apply -f "${TODO_APP_ROOT_MANIFESTS_DIR}/persistent_volume.yaml"
print_success "Persistent Volumes applied"

print_info "Applying Persistent Volume Claims..."
kubectl apply -f "${TODO_APP_ROOT_MANIFESTS_DIR}/persistent_volume_claim.yaml"
print_success "Persistent Volume Claims applied"

print_info "Applying Services..."
envsubst < "${TODO_APP_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
envsubst < "${TODO_APP_BACKEND_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
print_success "Services applied"

print_info "Applying Ingress..."
envsubst < "${TODO_APP_ROOT_MANIFESTS_DIR}/ingress.yaml" | kubectl apply -f -
print_success "Ingress applied"

print_header "⏳ WAITING FOR DEPLOYMENTS"
print_info "Waiting for todo-app-deployment to be available..."
kubectl rollout status deployment/todo-app-deployment --timeout=300s
kubectl wait --for=condition=available deployment/todo-app-deployment --timeout=300s
print_success "todo-app-deployment is ready"

print_header "📊 DEPLOYMENT STATUS"
print_info "Deployments:"
kubectl get deployments

print_info "Pods:"
kubectl get pods

print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=todo-app-deployment --timeout=60s
print_success "All pods are ready"

print_header "📝 APPLICATION LOGS"
kubectl logs deploy/todo-app-deployment --all-containers --tail=200

print_header "🎉 TODO APP DEPLOYMENT COMPLETE"
print_success "Todo app deployed successfully!"
print_info "Your todo application is now running in Kubernetes"

