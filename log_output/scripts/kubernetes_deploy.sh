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
PING_PONG_MANIFESTS_DIR="${PING_PONG_DIR}/manifests/statefulset"

# Build the Docker images (use absolute contexts)
print_header "🐳 BUILDING DOCKER IMAGES"
print_info "Building log_output image..."
docker buildx build --platform linux/amd64 -t log_output:amd64-v1 "${LOG_OUTPUT_DIR}"
print_success "log_output image built"

print_info "Building read_output image..."
docker buildx build --platform linux/amd64 -t read_output:amd64-v1 "${READ_OUTPUT_DIR}"
print_success "read_output image built"

print_info "Building ping_pong image..."
docker buildx build --platform linux/amd64 -t ping_pong:amd64-v1 "${PING_PONG_DIR}"
print_success "ping_pong image built"

print_info "Building ping_pong_db image..."
docker buildx build --platform linux/amd64 -t ping_pong_db:amd64-v1 "${PING_PONG_DIR}/database"
print_success "ping_pong_db image built"

# Tag the images for Docker Hub
print_header "🏷️  TAGGING IMAGES FOR DOCKER HUB"
docker tag log_output:amd64-v1 $_DOCKER_REGISTRY/log_output:amd64-v1
docker tag read_output:amd64-v1 $_DOCKER_REGISTRY/read_output:amd64-v1
docker tag ping_pong:amd64-v1 $_DOCKER_REGISTRY/ping_pong:amd64-v1
docker tag ping_pong_db:amd64-v1 $_DOCKER_REGISTRY/ping_pong_db:amd64-v1
print_success "All images tagged for Docker Hub"

# Push the Docker images to Docker Hub
print_header "📤 PUSHING IMAGES TO DOCKER HUB"
print_info "Pushing log_output image..."
docker push $_DOCKER_REGISTRY/log_output:amd64-v1
print_success "log_output pushed"

print_info "Pushing read_output image..."
docker push $_DOCKER_REGISTRY/read_output:amd64-v1
print_success "read_output pushed"

print_info "Pushing ping_pong image..."
docker push $_DOCKER_REGISTRY/ping_pong:amd64-v1
print_success "ping_pong pushed"

print_info "Pushing ping_pong_db image..."
docker push $_DOCKER_REGISTRY/ping_pong_db:amd64-v1
print_success "ping_pong_db pushed"

print_info "Cluster information:"
kubectl cluster-info

# Export variables for substitution in manifest
print_header "🔧 CONFIGURING ENVIRONMENT VARIABLES"
export DOCKER_REGISTRY=$_DOCKER_REGISTRY
export LOG_OUTPUT_PORT=4000
export PING_PONG_PORT=4001
export READ_OUTPUT_PORT=4002
export LOG_FILE_PATH="/usr/src/app/files/log.txt"
export REQUEST_COUNT_FILE_PATH="/usr/src/app/shared_files/count.txt"
export PING_PONG_URL="http://ping-pong-stset-svc:2346"
export PING_PONG_DB_URL="postgres://pingpong_user:pingpong_password@localhost:5432/pingpong_db"
print_success "Environment variables configured"

print_header "📁 NAMESPACE SETUP"
print_info "Creating namespace..."
kubectl create -f "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/namespace.yaml"
print_success "Namespace created"

# Block until the namespace actually exists (fail fast if it doesn't)
print_info "Waiting for namespace exercises to exist..."
NS_WAIT_TIMEOUT=100
for i in $(seq 1 $NS_WAIT_TIMEOUT); do
  if kubectl get namespace exercises >/dev/null 2>&1; then
    print_success "Namespace exercises is ready"
    break
  fi
  sleep 2
done
if ! kubectl get namespace exercises >/dev/null 2>&1; then
  print_error "Namespace exercises was not created within timeout. Please fix and retry."
  exit 1
fi

print_info "Activating namespace..."
kubens exercises
print_success "Namespace activated"

# Apply the Kubernetes manifest with substituted variables
print_info "Applying Persistent Volume Claims..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/persistent_volume_claim.yaml" | kubectl apply -f -
print_success "Persistent Volume Claims applied"

# Apply the Kubernetes manifest with substituted variables
print_header "📋 APPLYING KUBERNETES MANIFESTS"
print_info "Applying ConfigMap..."
kubectl apply -f "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/config_map.yaml"
print_success "ConfigMap applied"

print_info "Applying Deployments..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/deployment.yaml" | kubectl apply -f -
envsubst < "${PING_PONG_MANIFESTS_DIR}/statefulset.yaml" | kubectl apply -f -
print_success "Deployments applied"

print_info "Applying Services..."
envsubst < "${LOG_OUTPUT_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
envsubst < "${READ_OUTPUT_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
envsubst < "${PING_PONG_MANIFESTS_DIR}/headless_service.yaml" | kubectl apply -f -
envsubst < "${PING_PONG_MANIFESTS_DIR}/cluster_ip_service.yaml" | kubectl apply -f -
print_success "Services applied"

print_info "Applying Gateway..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/gateway.yaml" | kubectl apply -f -
print_success "Gateway applied"

print_info "Applying HTTP Routes..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/http_route.yaml" | kubectl apply -f -
envsubst < "${READ_OUTPUT_MANIFESTS_DIR}/http_route.yaml" | kubectl apply -f -
envsubst < "${PING_PONG_MANIFESTS_DIR}/http_route.yaml" | kubectl apply -f -
print_success "HTTP Routes applied"

print_info "Applying Gateway Rewrite Routes..."
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/gateway_rewrite_routes.yaml" | kubectl apply -f -
print_success "Gateway Rewrite Routes applied"

print_header "⏳ WAITING FOR DEPLOYMENTS"
print_info "Waiting for log-output-deployment to be available..."
kubectl rollout status deployment/log-output-deployment --timeout=100s
kubectl wait --for=condition=available deployment/log-output-deployment --timeout=300s
print_success "log-output-deployment is ready"

print_info "Waiting for ping-pong-stset to be available..."
kubectl rollout status statefulset/ping-pong-stset --timeout=100s
kubectl wait --for=condition=available statefulset/ping-pong-stset --timeout=100s
print_success "ping-pong-stset is ready"

print_header "📊 DEPLOYMENT STATUS"
print_info "Deployments:"
kubectl get deployments
print_info "Statefulsets:"
kubectl get statefulsets

print_header "🎉 DEPLOYMENT COMPLETE"
print_success "All applications deployed successfully!"
print_info "Your application is now running in Kubernetes"

