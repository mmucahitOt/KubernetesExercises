#!/bin/bash

# !!! IMPORTANT !!!
# This script is for setting up monitoring infrastructure only.
# Application deployment is handled by ArgoCD (GitOps).
# For building and pushing Docker images, use build-images.sh

# ============================================================================
# DESCRIPTION
# ============================================================================
# This script sets up monitoring infrastructure (Prometheus, Grafana, Alloy, Loki)
# for the todo_app application. It follows a hybrid approach:
#   - Helm charts for monitoring (Prometheus/Grafana/Alloy)
#   - Application deployment is handled by ArgoCD (GitOps)
#
# Supported Clusters:
#   - GKE (Google Kubernetes Engine) - fully supported
#   - k3d (local development) - fully supported
#   - Other Kubernetes clusters (EKS, AKS, etc.) - should work
#
# ============================================================================

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# ============================================================================
# CONFIGURATION
# ============================================================================
NAMESPACE="${NAMESPACE:-project}"
MONITORING_SCRIPTS="${MONITORING_SCRIPTS:-true}"

# Directory resolution
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
TODO_APP_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
MONITORING_DIR="${TODO_APP_ROOT}/scripts/monitoring"

# ============================================================================
# MAIN EXECUTION
# ============================================================================
print_header "📊 TODO APP - MONITORING INFRASTRUCTURE SETUP"
print_info "This script sets up monitoring infrastructure only."
print_info "Application deployment is handled by ArgoCD (GitOps)."
print_info "For building Docker images, use: ./scripts/build-images.sh <registry>"
print_info "Namespace: ${NAMESPACE}"

# ----------------------------------------------------------------------------
# KUBERNETES CLUSTER SETUP
# ----------------------------------------------------------------------------
print_header "☸️  KUBERNETES CLUSTER SETUP"

print_info "Cluster information:"
kubectl cluster-info

# Detect cluster type
IS_K3D=false
CLUSTER_NAME="${K3D_CLUSTER_NAME:-k3d-k3s-default}"
if command -v k3d >/dev/null 2>&1 && k3d cluster list 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
    IS_K3D=true
    print_info "Detected k3d cluster: ${CLUSTER_NAME}"
else
    print_info "Detected non-k3d cluster (GKE, EKS, AKS, etc.)"
fi

# Start cluster (only for k3d)
if [ "${IS_K3D}" = "true" ]; then
    print_info "Starting k3d cluster..."
    k3d cluster start "${CLUSTER_NAME}" || true
    print_success "Cluster started successfully"
else
    print_info "Skipping cluster start (not a k3d cluster - GKE clusters are always running)"
fi

# ----------------------------------------------------------------------------
# MONITORING SETUP (Hybrid Approach: Helm Charts)
# ----------------------------------------------------------------------------
print_header "📊 MONITORING SETUP"
if [ "${MONITORING_SCRIPTS}" = "true" ]; then
    print_info "MONITORING_SCRIPTS=true → running monitoring scripts"
    
    # Fix ClusterRole conflict if it exists from different namespace
    if kubectl get clusterrole grafana-alloy >/dev/null 2>&1; then
        CLUSTER_ROLE_NAMESPACE=$(kubectl get clusterrole grafana-alloy -o jsonpath='{.metadata.labels.meta\.helm\.sh/release-namespace}' 2>/dev/null || echo "")
        if [ -n "${CLUSTER_ROLE_NAMESPACE}" ] && [ "${CLUSTER_ROLE_NAMESPACE}" != "${NAMESPACE}" ]; then
            print_warning "ClusterRole 'grafana-alloy' exists from namespace '${CLUSTER_ROLE_NAMESPACE}'"
            print_info "Deleting old ClusterRole to avoid conflict..."
            kubectl delete clusterrole grafana-alloy || true
            print_success "Old ClusterRole deleted"
        fi
    fi
    
    # Step 1: Prometheus + Grafana Stack
    # Check for both possible filenames (prometheus vs prometheous typo)
    PROMETHEUS_SCRIPT=""
    if [ -f "${MONITORING_DIR}/step1_grafana_prometheus.sh" ]; then
        PROMETHEUS_SCRIPT="${MONITORING_DIR}/step1_grafana_prometheus.sh"
    elif [ -f "${MONITORING_DIR}/step1_grafana_prometheous.sh" ]; then
        PROMETHEUS_SCRIPT="${MONITORING_DIR}/step1_grafana_prometheous.sh"
    fi
    
    GRAFANA_INSTALLED=false
    if [ -n "${PROMETHEUS_SCRIPT}" ]; then
        print_info "Running Step 1: Prometheus + Grafana stack..."
        export NAMESPACE="${NAMESPACE}"
        if bash "${PROMETHEUS_SCRIPT}"; then
            GRAFANA_INSTALLED=true
            print_success "Step 1 completed - waiting for Grafana pods to be ready..."
            # Wait for Grafana pods to be ready before proceeding
            if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --namespace "${NAMESPACE}" --timeout=5m 2>/dev/null; then
                print_success "Grafana pods are ready"
            else
                print_warning "Grafana pods may not be ready yet, but continuing..."
            fi
        else
            print_warning "Prometheus/Grafana installation had issues (may already be installed)"
            # Check if Grafana is already installed
            if kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -q .; then
                GRAFANA_INSTALLED=true
                print_info "Grafana appears to be already installed"
            fi
        fi
    else
        print_warning "Monitoring script not found: ${MONITORING_DIR}/step1_grafana_prometheus.sh or step1_grafana_prometheous.sh"
    fi
    
    # Step 2: Grafana Alloy + Loki
    if [ -f "${MONITORING_DIR}/step2_grafana_alloy_loki.sh" ]; then
        print_info "Running Step 2: Grafana Alloy + Loki..."
        export NAMESPACE="${NAMESPACE}"
        bash "${MONITORING_DIR}/step2_grafana_alloy_loki.sh" || {
            print_warning "Grafana Alloy/Loki installation had issues (may already be installed)"
        }
        
        # Configure Grafana data sources (only if Grafana is installed)
        if [ "${GRAFANA_INSTALLED}" = "true" ]; then
            if [ -f "${MONITORING_DIR}/configure_grafana_datasources.sh" ]; then
                print_info "Configuring Grafana data sources..."
                export NAMESPACE="${NAMESPACE}"
                bash "${MONITORING_DIR}/configure_grafana_datasources.sh" || {
                    print_warning "Grafana data source configuration had issues"
                }
            fi
        else
            print_warning "Skipping Grafana data source configuration (Grafana not installed)"
        fi
    else
        print_warning "Monitoring script not found: ${MONITORING_DIR}/step2_grafana_alloy_loki.sh"
    fi
else
    print_info "MONITORING_SCRIPTS=false → skipping monitoring setup"
fi

# ----------------------------------------------------------------------------
# COMPLETION
# ----------------------------------------------------------------------------
print_header "✅ MONITORING SETUP COMPLETE"
print_success "Monitoring infrastructure has been set up."
print_info ""
print_info "Application deployment is handled by ArgoCD (GitOps)."
print_info "ArgoCD will automatically sync applications from Git repository."
print_info ""
print_info "To check ArgoCD application status:"
print_info "  kubectl get applications -n argocd"
print_info "  argocd app get todo-app"

print_header "📊 MONITORING ACCESS"
print_info "To access Grafana (monitoring dashboard):"
print_info "  kubectl -n ${NAMESPACE} port-forward \$(kubectl -n ${NAMESPACE} get pods -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus-stack -o jsonpath='{.items[0].metadata.name}') 3000:3000"
print_info "  Then visit: http://localhost:3000 (admin/admin123)"
print_info ""
print_info "To access Prometheus directly:"
print_info "  kubectl -n ${NAMESPACE} port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090"
print_info "  Then visit: http://localhost:9090"
print_info ""
print_info "To access Loki:"
print_info "  kubectl -n ${NAMESPACE} port-forward svc/loki 3100:3100"
print_info "  Then visit: http://localhost:3100"
print_info ""
print_info "To query logs in Grafana:"
print_info "  Use LogQL: {namespace=\"${NAMESPACE}\"} |= \"todo\""

