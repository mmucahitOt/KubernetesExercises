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
echo "📝 STEP 2: GRAFANA ALLOY + LOKI"
echo "=================================="

print_info "Setting up log collection with Grafana Alloy + Loki..."

# Get script directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# 1. Create simple Loki deployment using kubectl (avoiding Helm chart issues)
print_info "Creating simple Loki deployment with kubectl..."

# Apply Loki manifests from YAML files
print_info "Applying Loki ConfigMap..."
kubectl apply -f "${SCRIPT_DIR}/../../manifests/monitoring/loki-configmap.yaml"

print_info "Applying Loki Deployment..."
kubectl apply -f "${SCRIPT_DIR}/../../manifests/monitoring/loki-deployment.yaml"

print_info "Applying Loki Service..."
kubectl apply -f "${SCRIPT_DIR}/../../manifests/monitoring/loki-service.yaml"

# 2. Install Grafana Alloy for log collection
print_info "Installing Grafana Alloy for log collection..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana-alloy grafana/alloy --namespace project \
  --values "${SCRIPT_DIR}/../../manifests/monitoring/grafana-alloy-values.yaml"

if [ $? -eq 0 ]; then
  print_success "Loki and Grafana Alloy installed successfully"
else
  print_error "Failed to install Loki and Grafana Alloy"
  exit 1
fi

# 4. Wait for pods to be ready
print_info "Waiting for Loki and Grafana Alloy pods to be ready..."
kubectl wait --for=condition=ready pod -l app=loki --namespace project --timeout=5m
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=alloy --namespace project --timeout=5m
print_success "Loki and Grafana Alloy pods are ready"

# 5. Show status
print_info "Current status:"
kubectl get pods --namespace project -l "app=loki"
kubectl get pods --namespace project -l "app.kubernetes.io/name=alloy"
kubectl get services --namespace project -l "app=loki"
kubectl get services --namespace project -l "app.kubernetes.io/name=alloy"

# 6. Show access information
echo ""
print_success "🎉 Step 2 Complete: Loki + Grafana Alloy installed!"
echo ""
print_info "📝 What's included:"
print_info "  ✅ Loki (log storage with filesystem backend)"
print_info "  ✅ Grafana Alloy (modern log collection)"
print_info "  ✅ Automatic log collection from all pods"
print_info "  ✅ Kubernetes integration enabled"
print_info "  ✅ Single binary deployment (simple and reliable)"
echo ""
print_info "🔧 Next steps:"
print_info "  1. Configure Grafana to use Loki as data source"
print_info "  2. Test log collection from your todo app"
print_info "  3. Create dashboards for log analysis"
echo ""
print_info "📊 Access Loki:"
print_info "  kubectl -n project port-forward svc/loki 3100:3100"
print_info "  Then visit: http://localhost:3100"
echo ""
print_info "📊 Access Grafana Alloy:"
print_info "  kubectl -n project port-forward svc/grafana-alloy 12345:12345"
print_info "  Then visit: http://localhost:12345"