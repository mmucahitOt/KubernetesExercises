#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

echo "=================================="
echo "🔧 SETTING UP MONITORING ENVIRONMENT"
echo "=================================="

# Get namespace from environment or use default
NAMESPACE="${NAMESPACE:-project}"

print_info "Setting up monitoring environment for namespace: ${NAMESPACE}"

# Get script directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v helm >/dev/null 2>&1; then
    print_error "Helm is not installed. Please install Helm first."
    print_info "Install: https://helm.sh/docs/intro/install/"
    exit 1
fi
print_success "Helm is installed: $(helm version --short)"

if ! command -v kubectl >/dev/null 2>&1; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi
print_success "kubectl is installed: $(kubectl version --client --short)"

# Check cluster connectivity
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Connected to Kubernetes cluster"

# Ensure namespace exists
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    print_info "Creating namespace: ${NAMESPACE}"
    kubectl create namespace "${NAMESPACE}"
    print_success "Namespace created"
else
    print_info "Namespace ${NAMESPACE} already exists"
fi

echo ""
print_success "🎉 Monitoring environment setup complete!"
print_info "You can now run:"
print_info "  1. step1_grafana_prometheous.sh - Install Prometheus + Grafana"
print_info "  2. step2_grafana_alloy_loki.sh - Install Loki + Grafana Alloy"
print_info "  3. configure_grafana_datasources.sh - Configure Grafana data sources"
