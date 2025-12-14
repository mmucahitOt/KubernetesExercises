#!/bin/bash

# !!! IMPORTANT !!!
# the user should be logged in to Docker Hub before running this script
# docker login

# This script is used to deploy a canary release of the ping_pong application
# using Argo Rollouts for gradual traffic shifting.

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Get the registry name and image version from command line arguments
_DOCKER_REGISTRY=$1
_IMAGE_VERSION=${2:-amd64-v2}  # Default to v2 for canary, can be overridden

print_header "🚀 CANARY RELEASE DEPLOYMENT"
print_info "Registry: $_DOCKER_REGISTRY | Version: $_IMAGE_VERSION"

# Resolve directories relative to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd -P)"
PING_PONG_ROOT="$(cd -- "${LOG_OUTPUT_ROOT}/../ping_pong" >/dev/null 2>&1 && pwd -P)"
CANARY_RELEASE_DIR="${LOG_OUTPUT_ROOT}/manifests/canary_release"

# Build the Docker image
print_header "🐳 BUILDING DOCKER IMAGE"
print_info "Building ping_pong image (this may take a few minutes)..."
# Use --load so the buildx image is loaded into the local Docker daemon for tagging/pushing.
docker buildx build --platform linux/amd64 --no-cache --load -t ping_pong:${_IMAGE_VERSION} "${PING_PONG_ROOT}"

if [ $? -eq 0 ]; then
    print_success "Image built"
else
    print_error "Failed to build image"
    exit 1
fi

# Tag and push the image
print_header "📤 PUSHING IMAGE"
print_info "Pushing to Docker Hub..."
docker tag ping_pong:${_IMAGE_VERSION} $_DOCKER_REGISTRY/ping_pong:${_IMAGE_VERSION}
docker push $_DOCKER_REGISTRY/ping_pong:${_IMAGE_VERSION}

if [ $? -eq 0 ]; then
    print_success "Image pushed"
else
    print_error "Failed to push image"
    exit 1
fi

# Export variables for substitution in manifests
export DOCKER_REGISTRY=$_DOCKER_REGISTRY
export IMAGE_VERSION=$_IMAGE_VERSION
export PING_PONG_PORT=4001
export PING_PONG_DB_URL="postgres://pingpong_user:pingpong_password@ping-pong-stset-db-svc:5432/pingpong_db"

# Check prerequisites
print_header "🔍 CHECKING PREREQUISITES"
if ! kubectl get namespace exercises >/dev/null 2>&1; then
    print_error "Namespace 'exercises' does not exist. Run kubernetes_deploy.sh first"
    exit 1
fi

if ! kubectl get service ping-pong-deployment-svc -n exercises >/dev/null 2>&1; then
    print_error "Stable service 'ping-pong-deployment-svc' does not exist. Run kubernetes_deploy.sh first"
    exit 1
fi

kubens exercises >/dev/null 2>&1
print_success "Prerequisites OK"

# Check if Argo Rollouts is installed
if ! kubectl get crd rollouts.argoproj.io >/dev/null 2>&1; then
    print_warning "Installing Argo Rollouts..."
    kubectl create namespace argo-rollouts 2>/dev/null || true
    kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml >/dev/null 2>&1
    kubectl wait --for=condition=available deployment/argo-rollouts -n argo-rollouts --timeout=300s >/dev/null 2>&1 || true
fi

# Apply the Kubernetes manifests
print_header "📋 APPLYING MANIFESTS"
kubectl apply -f "${CANARY_RELEASE_DIR}/analysis_template.yaml" >/dev/null 2>&1 && print_success "AnalysisTemplate" || print_warning "AnalysisTemplate (may already exist)"
envsubst < "${CANARY_RELEASE_DIR}/canary_service.yaml" | kubectl apply -f - >/dev/null 2>&1 && print_success "Canary Service" || print_warning "Canary Service (may already exist)"
envsubst < "${CANARY_RELEASE_DIR}/rollout.yaml" | kubectl apply -f - >/dev/null 2>&1 && print_success "Rollout" || print_error "Failed to apply Rollout"

# Wait for rollout
print_header "⏳ WAITING FOR ROLLOUT"
print_info "Waiting for rollout to progress (this may take several minutes)..."
if kubectl argo rollouts version >/dev/null 2>&1; then
    kubectl argo rollouts status rollout ping-pong-rollout -n exercises --timeout=600s || {
        print_warning "Rollout status check completed or timed out"
    }
else
    print_info "Argo Rollouts plugin not found, using standard kubectl..."
    kubectl wait --for=condition=available rollout/ping-pong-rollout -n exercises --timeout=600s || {
        print_warning "Rollout may still be in progress"
    }
fi

# Show final status
print_header "📊 STATUS"
kubectl get rollout ping-pong-rollout -n exercises

print_header "🎉 DEPLOYMENT COMPLETE"
print_info "Commands:"
print_info "  Status: kubectl argo rollouts get rollout ping-pong-rollout -n exercises"
print_info "  Promote: kubectl argo rollouts promote ping-pong-rollout -n exercises"
print_info "  Abort: kubectl argo rollouts abort ping-pong-rollout -n exercises"