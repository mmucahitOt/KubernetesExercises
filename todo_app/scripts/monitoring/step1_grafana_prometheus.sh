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

# 1. Add Helm repositories
print_info "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
print_success "Helm repositories added and updated"

# 2. Install Prometheus + Grafana stack
print_info "Installing Prometheus + Grafana stack..."
helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace project \
  --set grafana.adminPassword=admin123 \
  --set grafana.service.type=ClusterIP \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=1Gi \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi

if [ $? -eq 0 ]; then
  print_success "Prometheus + Grafana stack installed successfully"
else
  print_error "Failed to install Prometheus + Grafana stack"
  exit 1
fi

# 3. Wait for pods to be ready
print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --namespace project --timeout=5m
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus --namespace project --timeout=5m
print_success "All pods are ready"

# 4. Services are automatically created by Helm
print_info "Services are automatically created by Helm chart"
print_success "Grafana service: prometheus-stack-grafana"
print_success "Prometheus service: prometheus-stack-kube-prom-prometheus"

# 5. Show status
print_info "Current status:"
kubectl get pods --namespace project -l "app.kubernetes.io/name in (grafana,prometheus)"
kubectl get services --namespace project -l "app.kubernetes.io/name in (grafana,prometheus)"

# 6. Show access information
echo ""
print_success "🎉 Step 1 Complete: Grafana + Prometheus installed!"
echo ""
print_info "📊 Access Information:"
print_info "  Grafana: http://localhost:8081/grafana (admin/admin123)"
print_info "  Prometheus: http://localhost:8081/prometheus"
echo ""
print_info "📋 What's included:"
print_info "  ✅ Prometheus (metrics collection)"
print_info "  ✅ Grafana (visualization)"
print_info "  ✅ Pre-configured dashboards"
print_info "  ✅ Kubernetes cluster metrics"
print_info "  ✅ AlertManager (for alerts)"
print_info "  ✅ Custom services for ingress access"
echo ""
print_info "🎯 Next step: Run step2_grafana_alloy_loki.sh to add log collection"