#!/bin/bash

# This script is used to undeploy the log_output application from a Kubernetes cluster.
# It is used to clean up the environment after testing.

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

# Get the registry name from the command line arguments
DOCKER_REGISTRY=$1

print_header "🧹 KUBERNETES UNDEPLOYMENT STARTING"
print_info "Docker Registry: $DOCKER_REGISTRY"
print_warning "This will remove all deployed resources"


EXISTING_CONTEXT=$(kubectl config get-contexts | grep "k3d-k3s-default")

print_header "☸️  CLUSTER CHECK"
if [ -z "$EXISTING_CONTEXT" ]; then
  print_warning "No existing cluster found"
  print_info "Nothing to undeploy"
else
  print_info "Existing cluster found"
  kubectl config use-context k3d-k3s-default
  print_success "Context switched to cluster"

  print_header "🗑️  DELETING KUBERNETES RESOURCES"
  
  print_info "Deleting Services..."
  kubectl delete service log-output-deployment-svc
  kubectl delete service ping-pong-deployment-svc
  print_success "Services deleted"

  print_info "Deleting Persistent Volume Claims..."
  kubectl delete pvc shared-claim
  print_success "PVCs deleted"

  print_info "Deleting Persistent Volumes..."
  kubectl delete pv persistent-volume-pv
  print_success "PV deleted"

  print_info "Deleting Deployments..."
  kubectl delete deployment log-output-deployment
  kubectl delete deployment ping-pong-deployment
  print_success "Deployments deleted"

  print_info "Deleting Namespace and ConfigMap..."
  kubectl delete namespaces exercises
  kubectl delete configmap log-output-configmap
  print_success "Namespace and ConfigMap deleted"

  print_header "🐳 CLEANING UP DOCKER IMAGES"
  print_info "Removing Docker images..."
  docker rmi $DOCKER_REGISTRY/log_output:latest
  docker rmi $DOCKER_REGISTRY/read_output:latest
  docker rmi $DOCKER_REGISTRY/ping_pong:latest
  print_success "Docker images removed"

  print_info "Switching to default namespace..."
  kubens default
  print_success "Namespace set to default"

  print_header "🎉 UNDEPLOYMENT COMPLETE"
  print_success "All resources have been cleaned up!"
  print_info "Environment is now clean and ready for next deployment"
fi
