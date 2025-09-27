#!/bin/bash

# !!! IMPORTANT !!!
# the user should be logged in to Docker Hub before running this script
# docker login

# This script is used to deploy the log_output application to a Kubernetes cluster.
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
LOG_OUTPUT_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
ROOT_DIR="$(cd -- "${LOG_OUTPUT_ROOT}/.." >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_DIR="${LOG_OUTPUT_ROOT}/log_output"
READ_OUTPUT_DIR="${LOG_OUTPUT_ROOT}/read_output"
PING_PONG_DIR="${ROOT_DIR}/ping_pong"
LOG_OUTPUT_ROOT_MANIFESTS_DIR="${LOG_OUTPUT_ROOT}/manifests"
LOG_OUTPUT_MANIFESTS_DIR="${LOG_OUTPUT_DIR}/manifests"
READ_OUTPUT_MANIFESTS_DIR="${READ_OUTPUT_DIR}/manifests"
PING_PONG_MANIFESTS_DIR="${PING_PONG_DIR}/manifests"

# Build the Docker images (use absolute contexts)
print_header "🐳 BUILDING DOCKER IMAGES"
print_info "Building log_output image..."
docker build -t log_output:latest "${LOG_OUTPUT_DIR}"
print_success "log_output image built"

print_info "Building read_output image..."
docker build -t read_output:latest "${READ_OUTPUT_DIR}"
print_success "read_output image built"

print_info "Building ping_pong image..."
docker build -t ping_pong:latest "${PING_PONG_DIR}"
print_success "ping_pong image built"

# Tag the images for Docker Hub
print_header "🏷️  TAGGING IMAGES FOR DOCKER HUB"
docker tag log_output:latest $_DOCKER_REGISTRY/log_output:latest
docker tag read_output:latest $_DOCKER_REGISTRY/read_output:latest
docker tag ping_pong:latest $_DOCKER_REGISTRY/ping_pong:latest
print_success "All images tagged for Docker Hub"

# Push the Docker images to Docker Hub
print_header "📤 PUSHING IMAGES TO DOCKER HUB"
print_info "Pushing log_output image..."
docker push $_DOCKER_REGISTRY/log_output:latest
print_success "log_output pushed"

print_info "Pushing read_output image..."
docker push $_DOCKER_REGISTRY/read_output:latest
print_success "read_output pushed"

print_info "Pushing ping_pong image..."
docker push $_DOCKER_REGISTRY/ping_pong:latest
print_success "ping_pong pushed"

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
export LOG_OUTPUT_PORT=4000
export PING_PONG_PORT=4001
export READ_OUTPUT_PORT=4002
export LOG_FILE_PATH="/usr/src/app/files/log.txt"
export REQUEST_COUNT_FILE_PATH="/usr/src/app/shared_files/count.txt"
export PING_PONG_URL="http://ping-pong-deployment-svc:2346"
print_success "Environment variables configured"

print_header "📁 NAMESPACE SETUP"
print_info "Creating namespace..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/namespace.yaml" | kubectl create -f -
print_success "Namespace created"

print_info "Activating namespace..."
kubens exercises
print_success "Namespace activated"

# Apply the Kubernetes manifest with substituted variables
print_header "📋 APPLYING KUBERNETES MANIFESTS"
print_info "Applying ConfigMap..."
kubectl apply -f "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/config_map.yaml"
print_success "ConfigMap applied"

print_info "Applying Deployments..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/deployment.yaml" | kubectl apply -f -
envsubst < "${PING_PONG_MANIFESTS_DIR}/deployment.yaml" | kubectl apply -f -
print_success "Deployments applied"

print_info "Applying Persistent Volumes..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/persistent_volume.yaml" | kubectl apply -f -
print_success "Persistent Volumes applied"

print_info "Applying Persistent Volume Claims..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/persistent_volume_claim.yaml" | kubectl apply -f -
print_success "Persistent Volume Claims applied"

print_info "Applying Services..."
envsubst < "${LOG_OUTPUT_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
envsubst < "${READ_OUTPUT_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
envsubst < "${PING_PONG_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
print_success "Services applied"

print_info "Applying Ingress..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/ingress.yaml" | kubectl apply -f -
print_success "Ingress applied"

print_header "⏳ WAITING FOR DEPLOYMENTS"
print_info "Waiting for log-output-deployment to be available..."
kubectl rollout status deployment/log-output-deployment --timeout=300s
kubectl wait --for=condition=available deployment/log-output-deployment --timeout=300s
print_success "log-output-deployment is ready"

print_info "Waiting for ping-pong-deployment to be available..."
kubectl rollout status deployment/ping-pong-deployment --timeout=300s
kubectl wait --for=condition=available deployment/ping-pong-deployment --timeout=300s
print_success "ping-pong-deployment is ready"

print_header "📊 DEPLOYMENT STATUS"
print_info "Deployments:"
kubectl get deployments

print_info "Pods:"
kubectl get pods

print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=log-output-deployment --timeout=60s
print_success "All pods are ready"

print_header "📝 APPLICATION LOGS"
kubectl logs deploy/log-output-deployment --all-containers --tail=200

print_header "🎉 DEPLOYMENT COMPLETE"
print_success "All services deployed successfully!"
print_info "Your application is now running in Kubernetes"

