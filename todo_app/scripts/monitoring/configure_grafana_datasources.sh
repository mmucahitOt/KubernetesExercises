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

# Get namespace from environment or use default
NAMESPACE="${NAMESPACE:-project}"

print_info "Configuring Grafana data sources for Loki and Prometheus..."

# Wait for Grafana to be installed and ready
print_info "Waiting for Grafana pods to be available..."
MAX_RETRIES=30
RETRY_COUNT=0
GRAFANA_POD=""

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    GRAFANA_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$GRAFANA_POD" ]; then
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        sleep 2
    fi
done

if [ -z "$GRAFANA_POD" ]; then
    print_error "Grafana pod not found in namespace $NAMESPACE after waiting"
    print_warning "Grafana may not be installed. Skipping data source configuration."
    print_info "To install Grafana, run: step1_grafana_prometheous.sh"
    exit 0  # Exit gracefully, not as error
fi

print_info "Found Grafana pod: $GRAFANA_POD"

# Wait for Grafana to be ready
print_info "Waiting for Grafana pod to be ready..."
if ! kubectl wait --for=condition=ready pod/$GRAFANA_POD -n $NAMESPACE --timeout=5m; then
    print_error "Grafana pod did not become ready within timeout"
    exit 1
fi

# Give Grafana a few more seconds to fully start its web server
print_info "Waiting for Grafana web server to be ready..."
sleep 10

# Configure Loki data source using full FQDN for better DNS resolution
print_info "Configuring Loki data source..."
LOKI_URL="http://loki.${NAMESPACE}.svc.cluster.local:3100"
kubectl exec -n $NAMESPACE $GRAFANA_POD -- \
  curl -X POST http://localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -u admin:admin123 \
  -d "{
    \"name\": \"Loki\",
    \"type\": \"loki\",
    \"url\": \"${LOKI_URL}\",
    \"access\": \"proxy\",
    \"isDefault\": false,
    \"jsonData\": {}
  }" 2>/dev/null | grep -q "Data source added" && print_success "Loki data source configured" || print_warning "Loki data source may already exist"

# Configure Prometheus data source using internal Kubernetes service name
print_info "Configuring Prometheus data source..."
PROMETHEUS_URL="http://prometheus-stack-kube-prom-prometheus:9090"
kubectl exec -n $NAMESPACE $GRAFANA_POD -- \
  curl -X POST http://localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -u admin:admin123 \
  -d "{
    \"name\": \"Prometheus\",
    \"type\": \"prometheus\",
    \"url\": \"${PROMETHEUS_URL}\",
    \"access\": \"proxy\",
    \"isDefault\": true,
    \"jsonData\": {}
  }" 2>/dev/null | grep -q "Data source added" && print_success "Prometheus data source configured" || print_warning "Prometheus data source may already exist"

echo ""
print_success "🎉 Grafana data sources configuration complete!"
echo ""
print_info "📊 Access Grafana:"
print_info "  kubectl -n $NAMESPACE port-forward svc/prometheus-stack-grafana 3000:80"
print_info "  Then visit: http://localhost:3000 (admin/admin123)"
echo ""
print_info "📝 You can now:"
print_info "  - Query logs in Grafana Explore using LogQL"
print_info "  - Example query: {namespace=\"${NAMESPACE}\"} |= \"log-output\""
print_info "  - View metrics in pre-configured dashboards"