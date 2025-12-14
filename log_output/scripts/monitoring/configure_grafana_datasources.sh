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
echo "🔧 CONFIGURING GRAFANA DATA SOURCES"
echo "=================================="

NAMESPACE="exercises"

print_info "Configuring Grafana data sources for Loki and Prometheus..."

# Get Grafana pod name
GRAFANA_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

if [ -z "$GRAFANA_POD" ]; then
  print_error "Grafana pod not found in namespace $NAMESPACE"
  exit 1
fi

print_info "Found Grafana pod: $GRAFANA_POD"

# Wait for Grafana to be ready
print_info "Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod/$GRAFANA_POD -n $NAMESPACE --timeout=2m

# Configure Loki data source
print_info "Configuring Loki data source..."
kubectl exec -n $NAMESPACE $GRAFANA_POD -- \
  curl -X POST http://localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -u admin:admin123 \
  -d '{
    "name": "Loki",
    "type": "loki",
    "url": "http://loki:3100",
    "access": "proxy",
    "isDefault": false,
    "jsonData": {}
  }' 2>/dev/null | grep -q "Data source added" && print_success "Loki data source configured" || print_warning "Loki data source may already exist"

# Prometheus should already be configured by the Helm chart
print_info "Prometheus data source should be auto-configured by Helm chart"

echo ""
print_success "🎉 Grafana data sources configuration complete!"
echo ""
print_info "📊 Access Grafana:"
print_info "  kubectl -n $NAMESPACE port-forward svc/prometheus-stack-grafana 3000:80"
print_info "  Then visit: http://localhost:3000 (admin/admin123)"
echo ""
print_info "📝 You can now:"
print_info "  - Query logs in Grafana Explore using LogQL"
print_info "  - Example query: {namespace=\"exercises\"} |= \"log-output\""
print_info "  - View metrics in pre-configured dashboards"