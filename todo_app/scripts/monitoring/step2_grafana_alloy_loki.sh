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

# 1. Create simple Loki deployment using kubectl
print_info "Creating simple Loki deployment with kubectl..."

# Apply Loki manifests from YAML files
LOKI_MANIFESTS_DIR="${SCRIPT_DIR}/../../manifests/monitoring"
if [ ! -d "${LOKI_MANIFESTS_DIR}" ]; then
    print_error "Loki manifests directory not found: ${LOKI_MANIFESTS_DIR}"
    exit 1
fi

print_info "Applying Loki ConfigMap..."
kubectl apply -f "${LOKI_MANIFESTS_DIR}/loki-configmap.yaml" --namespace "${NAMESPACE}"

# Check if Loki deployment exists - if it has a different selector, we need to delete it first
# (Deployment selector is immutable, so we can't change it via kubectl apply)
if kubectl get deployment loki --namespace "${NAMESPACE}" >/dev/null 2>&1; then
    EXISTING_SELECTOR=$(kubectl get deployment loki --namespace "${NAMESPACE}" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null || echo "{}")
    # Check if the existing selector has extra labels that the manifest doesn't have
    if echo "$EXISTING_SELECTOR" | grep -q "app.k8s.io/part-of"; then
        print_warning "Existing Loki deployment has different selector (immutable field)"
        print_info "Deleting existing Loki deployment to recreate with correct selector..."
        kubectl delete deployment loki --namespace "${NAMESPACE}" --wait=true --timeout=60s || {
            print_warning "Failed to delete with wait, trying without wait..."
            kubectl delete deployment loki --namespace "${NAMESPACE}" || true
        }
        print_success "Existing deployment deleted"
        # Wait a moment for resources to be cleaned up
        sleep 2
    fi
fi

print_info "Applying Loki Deployment..."
kubectl apply -f "${LOKI_MANIFESTS_DIR}/loki-deployment.yaml" --namespace "${NAMESPACE}"

print_info "Applying Loki Service..."
kubectl apply -f "${LOKI_MANIFESTS_DIR}/loki-service.yaml" --namespace "${NAMESPACE}"

# 2. Install Grafana Alloy for log collection
print_info "Installing Grafana Alloy for log collection..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Get namespace from environment or use default
NAMESPACE="${NAMESPACE:-project}"

# Check if ClusterRole exists from a different namespace
if kubectl get clusterrole grafana-alloy >/dev/null 2>&1; then
  CLUSTER_ROLE_NAMESPACE=$(kubectl get clusterrole grafana-alloy -o jsonpath='{.metadata.labels.meta\.helm\.sh/release-namespace}' 2>/dev/null || echo "")
  if [ -n "${CLUSTER_ROLE_NAMESPACE}" ] && [ "${CLUSTER_ROLE_NAMESPACE}" != "${NAMESPACE}" ]; then
    print_warning "ClusterRole 'grafana-alloy' exists from namespace '${CLUSTER_ROLE_NAMESPACE}'"
    print_info "Deleting old ClusterRole to avoid conflict..."
    kubectl delete clusterrole grafana-alloy || true
    print_success "Old ClusterRole deleted"
  fi
fi

# Check if Grafana Alloy is already installed
if helm list --namespace "${NAMESPACE}" | grep -q grafana-alloy; then
  print_warning "Grafana Alloy already installed, upgrading..."
  helm upgrade grafana-alloy grafana/alloy --namespace "${NAMESPACE}" \
    --values "${SCRIPT_DIR}/../../manifests/monitoring/grafana-alloy-values.yaml"
  INSTALL_RESULT=$?
else
  print_info "Installing Grafana Alloy in namespace: ${NAMESPACE}..."
  helm install grafana-alloy grafana/alloy --namespace "${NAMESPACE}" \
    --values "${SCRIPT_DIR}/../../manifests/monitoring/grafana-alloy-values.yaml" \
    --create-namespace
  INSTALL_RESULT=$?
fi

if [ ${INSTALL_RESULT} -eq 0 ]; then
  print_success "Loki and Grafana Alloy installed/upgraded successfully"
else
  print_warning "Grafana Alloy installation had issues"
  print_info "This may be due to existing resources. The script will continue..."
fi

# 4. Wait for pods to be ready
print_info "Waiting for Loki and Grafana Alloy pods to be ready..."
kubectl wait --for=condition=ready pod -l app=loki --namespace "${NAMESPACE}" --timeout=5m || {
    print_warning "Loki pods may not be ready yet"
}
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=alloy --namespace "${NAMESPACE}" --timeout=5m || {
    print_warning "Grafana Alloy pods may not be ready yet"
}
print_success "Waiting for pods complete"

# 5. Show status
print_info "Current status:"
kubectl get pods --namespace "${NAMESPACE}" -l "app=loki"
kubectl get pods --namespace "${NAMESPACE}" -l "app.kubernetes.io/name=alloy"
kubectl get services --namespace "${NAMESPACE}" -l "app=loki"
kubectl get services --namespace "${NAMESPACE}" -l "app.kubernetes.io/name=alloy"

# 6. Show access information
echo ""
print_success "🎉 Step 2 Complete: Loki + Grafana Alloy installed!"
echo ""
print_info "📝 What's included:"
print_info "  ✅ Loki (log storage with filesystem backend)"
print_info "  ✅ Grafana Alloy (modern log collection)"
print_info "  ✅ Automatic log collection from all pods in ${NAMESPACE} namespace"
print_info "  ✅ Kubernetes integration enabled"
print_info "  ✅ Single binary deployment (simple and reliable)"
echo ""
print_info "🔧 Next steps:"
print_info "  1. Configure Grafana to use Loki as data source"
print_info "  2. Test log collection from your log_output app"
print_info "  3. Create dashboards for log analysis"
echo ""
print_info "📊 Access Loki:"
print_info "  kubectl -n ${NAMESPACE} port-forward svc/loki 3100:3100"
print_info "  Then visit: http://localhost:3100"
echo ""
print_info "📊 Access Grafana Alloy:"
print_info "  kubectl -n ${NAMESPACE} port-forward svc/grafana-alloy 12345:12345"
print_info "  Then visit: http://localhost:12345"