#!/bin/bash

# This script is used to undeploy the todo_app application from a Kubernetes cluster.
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

print_header "🧹 TODO APP UNDEPLOYMENT STARTING"
print_info "Docker Registry: $DOCKER_REGISTRY"
print_warning "This will remove all deployed todo app resources"


EXISTING_CONTEXT=$(kubectl config get-contexts | grep "k3d-k3s-default")

print_header "☸️  CLUSTER CHECK"
if [ -z "$EXISTING_CONTEXT" ]; then
  print_warning "No existing cluster found"
  print_info "Nothing to undeploy"
else
  print_info "Existing cluster found"
  kubectl config use-context k3d-k3s-default
  print_success "Context switched to cluster"

  print_header "🗑️  DELETING TODO APP RESOURCES"
  
  print_info "Deleting Services..."
  kubectl delete service todo-app-svc
  kubectl delete service todo-app-backend-svc
  kubectl delete todo-stset-db-svc
  print_success "Services deleted"

  print_info "Deleting Persistent Volume Claims..."
  kubectl delete pvc todo-app-claim
  kubectl delete pvs todo-app-data-storage
  print_success "PVCs deleted"

  print_info "Deleting Persistent Volumes..."
  kubectl delete pv todo-app-volume
  print_success "PV deleted"

  print_info "Deleting Statefulsets..."
  kubectl delete statefulset todo-app-stset
  print_success "Statefulsets deleted"

  print_info "Deleting Namespace and ConfigMap..."
  kubectl delete namespaces project
  kubectl delete configmap todo-app-configmap
  print_success "Namespace and ConfigMap deleted"

  print_header "🐳 CLEANING UP DOCKER IMAGES"
  print_info "Removing Docker images..."
  docker rmi $DOCKER_REGISTRY/todo_output:latest
  print_success "Docker images removed"

  print_header "🎉 TODO APP UNDEPLOYMENT COMPLETE"
  print_success "All todo app resources have been cleaned up!"
  print_info "Environment is now clean and ready for next stset"
fi
