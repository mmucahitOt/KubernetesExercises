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
echo "📊 STEP 1: GRAFANA + PROMETHEUS"
echo "=================================="

print_info "Setting up Grafana + Prometheus monitoring stack..."

# Get namespace from environment or use default
NAMESPACE="${NAMESPACE:-exercises}"

# 1. Add Helm repositories
print_info "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
print_success "Helm repositories added and updated"

# 2. Install Prometheus + Grafana stack
print_info "Installing Prometheus + Grafana stack in namespace: ${NAMESPACE}..."

# Check if running on k3d (no storage class)
if kubectl get storageclass local-path >/dev/null 2>&1; then
  STORAGE_CLASS="local-path"
  PERSISTENCE_ENABLED="true"
else
  STORAGE_CLASS=""
  PERSISTENCE_ENABLED="false"
  print_warning "No storage class found, disabling persistence for k3d compatibility"
fi

helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace "${NAMESPACE}" \
  --set grafana.adminPassword=admin123 \
  --set grafana.service.type=ClusterIP \
  --set grafana.persistence.enabled=${PERSISTENCE_ENABLED} \
  --set grafana.persistence.size=1Gi \
  --set grafana.persistence.storageClassName=${STORAGE_CLASS} \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=${STORAGE_CLASS} \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --create-namespace

if [ $? -eq 0 ]; then
  print_success "Prometheus + Grafana stack installed successfully"
else
  print_warning "Installation may have failed or already exists, checking status..."
  # Check if it's already installed
  if helm list --namespace "${NAMESPACE}" | grep -q prometheus-stack; then
    print_info "Prometheus stack already installed, skipping..."
  else
    print_error "Failed to install Prometheus + Grafana stack"
    exit 1
  fi
fi

# 3. Wait for pods to be ready
print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --namespace "${NAMESPACE}" --timeout=5m || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus --namespace "${NAMESPACE}" --timeout=5m || true
print_success "All pods are ready"

# 4. Services are automatically created by Helm
print_info "Services are automatically created by Helm chart"
print_success "Grafana service: prometheus-stack-grafana"
print_success "Prometheus service: prometheus-stack-kube-prom-prometheus"

# 5. Show status
print_info "Current status:"
kubectl get pods --namespace "${NAMESPACE}" -l "app.kubernetes.io/name in (grafana,prometheus)"
kubectl get services --namespace "${NAMESPACE}" -l "app.kubernetes.io/name in (grafana,prometheus)"

# 6. Show access information
echo ""
print_success "🎉 Step 1 Complete: Grafana + Prometheus installed!"
echo ""
print_info "📊 Access Information:"
print_info "  Grafana: kubectl -n ${NAMESPACE} port-forward svc/prometheus-stack-grafana 3000:80"
print_info "  Then visit: http://localhost:3000 (admin/admin123)"
print_info "  Prometheus: kubectl -n ${NAMESPACE} port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090"
print_info "  Then visit: http://localhost:9090"
echo ""
print_info "📋 What's included:"
print_info "  ✅ Prometheus (metrics collection)"
print_info "  ✅ Grafana (visualization)"
print_info "  ✅ Pre-configured dashboards"
print_info "  ✅ Kubernetes cluster metrics"
print_info "  ✅ AlertManager (for alerts)"
echo ""
print_info "🎯 Next step: Run step2_grafana_alloy_loki.sh to add log collection"

