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
echo "🔧 CONFIGURE GRAFANA DATA SOURCES"
echo "=================================="

print_info "Configuring Grafana data sources for Loki and Prometheus..."

# Get Grafana pod name
GRAFANA_POD=$(kubectl -n project get pods -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus-stack" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$GRAFANA_POD" ]; then
  GRAFANA_POD=$(kubectl -n project get pods -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
fi

if [ -z "$GRAFANA_POD" ]; then
  print_error "Grafana pod not found. Ensure Grafana is deployed and running."
  exit 1
fi

print_info "Grafana pod found: $GRAFANA_POD"

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret --namespace project prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode 2>/dev/null)
if [ -z "$GRAFANA_PASSWORD" ]; then
  GRAFANA_PASSWORD="admin123" # Fallback to default
  print_warning "Could not retrieve Grafana admin password from secret. Using default 'admin123'."
fi

# Port-forward Grafana temporarily to configure
print_info "Setting up temporary port-forward to Grafana for configuration..."
kubectl -n project port-forward "$GRAFANA_POD" 3000:3000 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 5 # Give port-forward time to establish

if ! lsof -i :3000 >/dev/null 2>&1; then
  print_error "Failed to establish port-forward to Grafana. Exiting."
  kill $PORT_FORWARD_PID 2>/dev/null
  exit 1
fi

print_success "Port-forward established. Configuring data sources..."

# Add Prometheus data source (if not already exists)
print_info "Adding/updating Prometheus data source..."
curl -s -X POST -H "Content-Type: application/json" \
  -u admin:"$GRAFANA_PASSWORD" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus-stack-kube-prom-prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }' http://localhost:3000/api/datasources >/dev/null

if [ $? -eq 0 ]; then
  print_success "Prometheus data source added/updated in Grafana."
else
  print_warning "Failed to add Prometheus data source. It might already exist."
fi

# Add Loki data source (if Loki is installed)
if kubectl -n project get pods -l app.kubernetes.io/name=loki >/dev/null 2>&1; then
  print_info "Adding/updating Loki data source..."
  curl -s -X POST -H "Content-Type: application/json" \
    -u admin:"$GRAFANA_PASSWORD" \
    -d '{
      "name": "Loki",
      "type": "loki",
      "url": "http://loki:3100",
      "access": "proxy"
    }' http://localhost:3000/api/datasources >/dev/null

  if [ $? -eq 0 ]; then
    print_success "Loki data source added/updated in Grafana."
  else
    print_warning "Failed to add Loki data source. It might already exist."
  fi
else
  print_info "Loki not detected, skipping Loki data source configuration."
fi

print_info "Cleaning up port-forward..."
kill $PORT_FORWARD_PID 2>/dev/null
print_success "Grafana data source configuration complete."

echo ""
print_success "🎉 Data sources configured!"
echo ""
print_info "📊 Access Grafana:"
print_info "  1. kubectl -n project port-forward \$(kubectl -n project get pods -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus-stack -o jsonpath='{.items[0].metadata.name}') 3000:3000"
print_info "  2. Visit: http://localhost:3000 (admin/$GRAFANA_PASSWORD)"
print_info "  3. Go to 'Explore' to query logs and metrics"
echo ""
print_info "📝 Sample LogQL queries for your todo backend:"
print_info "  {job=\"kubernetes-logs\", namespace=\"project\"} |= \"todo\""
print_info "  {job=\"kubernetes-logs\", namespace=\"project\", container=\"todo-app-backend\"}"
print_info "  {job=\"kubernetes-logs\", namespace=\"project\"} |= \"Error\""
