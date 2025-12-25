#!/bin/bash

# !!! IMPORTANT !!!
# This script is for setting up monitoring infrastructure only.
# Application deployment is handled by ArgoCD (GitOps).
# For building and pushing Docker images, use build-images.sh

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored headers
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

# Function to print colored info
print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Function to print colored success
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print colored warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print colored error
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
MONITORING_DIR="${LOG_OUTPUT_ROOT}/scripts/monitoring"

print_header "📊 MONITORING INFRASTRUCTURE SETUP"
print_info "This script sets up monitoring infrastructure only."
print_info "Application deployment is handled by ArgoCD (GitOps)."
print_info "For building Docker images, use: ./scripts/build-images.sh <registry>"

MONITORING_SCRIPTS="${MONITORING_SCRIPTS:-true}"

print_header "📊 MONITORING SETUP"
if [ "${MONITORING_SCRIPTS}" = "true" ]; then
    print_info "MONITORING_SCRIPTS=true → running monitoring scripts"
    
    # Step 1: Prometheus + Grafana Stack
    if [ -f "${MONITORING_DIR}/step1_grafana_prometheus.sh" ]; then
        print_info "Running Step 1: Prometheus + Grafana stack..."
        bash "${MONITORING_DIR}/step1_grafana_prometheus.sh" || {
            print_warning "Prometheus/Grafana installation had issues (may already be installed)"
        }
    else
        print_warning "Monitoring script not found: ${MONITORING_DIR}/step1_grafana_prometheus.sh"
    fi
    
    # Step 2: Grafana Alloy + Loki
    if [ -f "${MONITORING_DIR}/step2_grafana_alloy_loki.sh" ]; then
        print_info "Running Step 2: Grafana Alloy + Loki..."
        bash "${MONITORING_DIR}/step2_grafana_alloy_loki.sh" || {
            print_warning "Grafana Alloy/Loki installation had issues (may already be installed)"
        }
        
        # Configure Grafana data sources
        if [ -f "${MONITORING_DIR}/configure_grafana_datasources.sh" ]; then
            print_info "Configuring Grafana data sources..."
            bash "${MONITORING_DIR}/configure_grafana_datasources.sh" || {
                print_warning "Grafana data source configuration had issues"
            }
        fi
    else
        print_warning "Monitoring script not found: ${MONITORING_DIR}/step2_grafana_alloy_loki.sh"
    fi
else
    print_info "MONITORING_SCRIPTS=false → skipping monitoring setup"
fi

print_header "✅ MONITORING SETUP COMPLETE"
print_info "Monitoring infrastructure has been set up."
print_info ""
print_info "Application deployment is handled by ArgoCD (GitOps)."
print_info "ArgoCD will automatically sync applications from Git repository."
print_info ""
print_info "To check ArgoCD application status:"
print_info "  kubectl get applications -n argocd"
print_info "  argocd app get log-output-app"

print_header "📊 MONITORING ACCESS"
print_info "To access Grafana (monitoring dashboard):"
print_info "  kubectl -n exercises port-forward svc/prometheus-stack-grafana 3000:80"
print_info "  Then visit: http://localhost:3000 (admin/admin123)"
print_info ""
print_info "To access Prometheus directly:"
print_info "  kubectl -n exercises port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090"
print_info "  Then visit: http://localhost:9090"
print_info ""
print_info "To access Loki:"
print_info "  kubectl -n exercises port-forward svc/loki 3100:3100"
print_info "  Then visit: http://localhost:3100"
print_info ""
print_info "To query logs in Grafana:"
print_info "  Use LogQL: {namespace=\"exercises\"} |= \"log-output\""