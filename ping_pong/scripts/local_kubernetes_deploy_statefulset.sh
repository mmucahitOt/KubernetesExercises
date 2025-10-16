#!/bin/bash

# !!! IMPORTANT !!!
# the user should be logged in to Docker Hub before running this script
# docker login

# This script is used to deploy the ping_pong application to a Kubernetes cluster.
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

print_header "🚀 KUBERNETES DEPLOYMENT STARTING"
print_info "Docker Registry: $_DOCKER_REGISTRY"
print_info "Ports: LOG_OUTPUT=4000, PING_PONG=4001, READ_OUTPUT=4002"

# Resolve directories relative to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PING_PONG_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
ROOT_DIR="$(cd -- "${PING_PONG_ROOT}/.." >/dev/null 2>&1 && pwd -P)"
PING_PONG_DIR="${ROOT_DIR}/ping_pong"
PING_PONG_MANIFESTS_DIR="${PING_PONG_DIR}/manifests/statefulset"

# Build the Docker images (use absolute contexts)
print_header "🐳 BUILDING DOCKER IMAGES"

print_info "Building ping_pong image..."
docker build -t ping_pong:latest "${PING_PONG_DIR}"
print_success "ping_pong image built"

print_info "Building ping_pong_db image..."
docker build -t ping_pong_db:latest "${PING_PONG_DIR}/database"
print_success "ping_pong_db image built"

# Tag the images for Docker Hub
print_header "🏷️  TAGGING IMAGES FOR DOCKER HUB"
docker tag ping_pong:latest $_DOCKER_REGISTRY/ping_pong:latest
docker tag ping_pong_db:latest $_DOCKER_REGISTRY/ping_pong_db:latest
print_success "All images tagged for Docker Hub"


# Push the Docker images to Docker Hub
print_header "📤 PUSHING IMAGES TO DOCKER HUB"

print_info "Pushing ping_pong image..."
docker push $_DOCKER_REGISTRY/ping_pong:latest
print_success "ping_pong pushed"

print_info "Pushing ping_pong_db image..."
docker push $_DOCKER_REGISTRY/ping_pong_db:latest
print_success "ping_pong_db pushed"
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

# Export variables for substitution in manifest
print_header "🔧 CONFIGURING ENVIRONMENT VARIABLES"
export DOCKER_REGISTRY=$_DOCKER_REGISTRY
export PING_PONG_PORT=4001
export LOG_FILE_PATH="/usr/src/app/files/log.txt"
export REQUEST_COUNT_FILE_PATH="/usr/src/app/shared_files/count.txt"
export PING_PONG_URL="http://ping-pong-deployment-svc:2346"
export PING_PONG_DB_URL="postgres://pingpong_user:pingpong_password@localhost:5432/pingpong_db"
print_success "Environment variables configured"

print_header "📁 NAMESPACE SETUP"
print_info "Creating namespace..."
kubectl create -f "${PING_PONG_MANIFESTS_DIR}/namespace.yaml"
print_success "Namespace created"

print_info "Activating namespace..."
kubens ping_pong
print_success "Namespace activated"

# Apply the Kubernetes manifest with substituted variables
print_header "📋 APPLYING KUBERNETES MANIFESTS"

print_info "Applying Statefulses..."
envsubst < "${PING_PONG_MANIFESTS_DIR}/statefulset.yaml" | kubectl apply -f -
print_success "Statefulset applied"


print_info "Applying Services..."
envsubst < "${PING_PONG_MANIFESTS_DIR}/headless_service.yaml" | kubectl apply -f -
envsubst < "${PING_PONG_MANIFESTS_DIR}/cluster_ip_service.yaml" | kubectl apply -f -
print_success "Services applied"

print_info "Applying Loadbalancer..."
envsubst < "${PING_PONG_MANIFESTS_DIR}/loadbalancer.yaml" | kubectl apply -f -
print_success "Loadbalancer applied"

print_header "🎉 DEPLOYMENT COMPLETE"
print_success "All services deployed successfully!"
print_info "Your application is now running in Kubernetes"

