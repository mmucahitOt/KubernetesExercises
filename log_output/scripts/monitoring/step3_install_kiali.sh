#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

echo "=================================="
echo "🔍 STEP 3: INSTALL KIALI"
echo "=================================="

NAMESPACE="${NAMESPACE:-exercises}"

print_info "Installing Kiali for service mesh observability..."

if ! kubectl get namespace istio-system >/dev/null 2>&1; then
  print_error "Istio is not installed. Please install Istio first."
  exit 1
fi

print_success "Istio namespace found"

PROMETHEUS_SVC=""
PROMETHEUS_NAMESPACE=""

if kubectl get svc -n "${NAMESPACE}" prometheus-stack-kube-prom-prometheus >/dev/null 2>&1; then
  PROMETHEUS_SVC="prometheus-stack-kube-prom-prometheus"
  PROMETHEUS_NAMESPACE="${NAMESPACE}"
  print_success "Found Prometheus service: ${PROMETHEUS_SVC} in namespace ${PROMETHEUS_NAMESPACE}"
elif kubectl get svc -n monitoring prometheus-stack-kube-prom-prometheus >/dev/null 2>&1; then
  PROMETHEUS_SVC="prometheus-stack-kube-prom-prometheus"
  PROMETHEUS_NAMESPACE="monitoring"
  print_success "Found Prometheus service: ${PROMETHEUS_SVC} in namespace ${PROMETHEUS_NAMESPACE}"
else
  print_warning "Prometheus service not found. Searching for any Prometheus service..."
  PROMETHEUS_SVC=$(kubectl get svc -A -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  PROMETHEUS_NAMESPACE=$(kubectl get svc -A -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "")
  
  if [ -z "${PROMETHEUS_SVC}" ]; then
    print_error "Prometheus service not found. Please install Prometheus first."
    print_info "Run: bash step1_grafana_prometheus.sh"
    exit 1
  fi
  print_success "Found Prometheus service: ${PROMETHEUS_SVC} in namespace ${PROMETHEUS_NAMESPACE}"
fi

print_info "Adding Kiali Helm repository..."
helm repo add kiali https://kiali.org/helm-charts
helm repo update
print_success "Kiali Helm repository added"

print_info "Installing Kiali in istio-system namespace..."

KIALI_VALUES=$(cat <<EOF
auth:
  strategy: "anonymous"
deployment:
  ingress_enabled: false
  service_type: ClusterIP
external_services:
  prometheus:
    url: "http://${PROMETHEUS_SVC}.${PROMETHEUS_NAMESPACE}.svc.cluster.local:9090"
  grafana:
    enabled: true
    in_cluster_url: "http://prometheus-stack-grafana.${NAMESPACE}.svc.cluster.local:80"
  tracing:
    enabled: false
server:
  web_root: "/kiali"
EOF
)

if helm list -n istio-system | grep -q kiali; then
  print_warning "Kiali already installed, upgrading..."
  echo "${KIALI_VALUES}" | helm upgrade kiali kiali/kiali-server \
    -n istio-system \
    -f -
else
  print_info "Installing Kiali..."
  echo "${KIALI_VALUES}" | helm install kiali kiali/kiali-server \
    -n istio-system \
    --create-namespace \
    -f -
fi

if [ $? -eq 0 ]; then
  print_success "Kiali installed/upgraded successfully"
else
  print_error "Failed to install Kiali"
  exit 1
fi

print_info "Waiting for Kiali pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kiali -n istio-system --timeout=5m || {
  print_warning "Kiali pod not ready yet, but continuing..."
}

print_info "Creating ServiceMonitor and PodMonitor for Istio metrics..."
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
kubectl apply -f "${SCRIPT_DIR}/../../manifests/monitoring/istio-servicemonitor.yaml" || {
  print_warning "Failed to create ServiceMonitor/PodMonitor, but continuing..."
}

print_info "Current Kiali status:"
kubectl get pods -n istio-system -l app.kubernetes.io/name=kiali
kubectl get svc -n istio-system -l app.kubernetes.io/name=kiali

echo ""
print_success "🎉 Kiali installation complete!"
echo ""
print_info "📊 Access Kiali:"
print_info "  kubectl -n istio-system port-forward svc/kiali 20001:20001"
print_info "  Then visit: http://localhost:20001/kiali"
echo ""
print_info "🔧 Configuration:"
print_info "  ✅ Prometheus: ${PROMETHEUS_SVC}.${PROMETHEUS_NAMESPACE}.svc.cluster.local:9090"
print_info "  ✅ Grafana: prometheus-stack-grafana.${NAMESPACE}.svc.cluster.local:80"
print_info "  ✅ Auth: Anonymous (no login required)"
echo ""
print_info "📋 What you can do in Kiali:"
print_info "  - View service mesh topology"
print_info "  - See traffic flow between services"
print_info "  - Monitor traffic splitting (75/25 for greeter)"
print_info "  - View metrics and health status"
print_info "  - Access Grafana dashboards from Kiali"
echo ""

