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
echo "🧹 MONITORING ENVIRONMENT CLEANUP"
echo "=================================="

print_info "Starting complete cleanup of monitoring environment..."

# 1. Delete all Helm releases
print_info "Deleting Helm releases..."
helm uninstall prometheus-stack --namespace project 2>/dev/null && print_success "Prometheus-stack Helm release deleted" || print_warning "Prometheus-stack Helm release not found"
helm uninstall loki --namespace project 2>/dev/null && print_success "Loki Helm release deleted" || print_warning "Loki Helm release not found"
helm uninstall grafana-alloy --namespace project 2>/dev/null && print_success "Grafana Alloy Helm release deleted" || print_warning "Grafana Alloy Helm release not found"

# 2. Clean up cluster-scoped resources
print_info "Cleaning up cluster-scoped resources..."
kubectl get clusterroles | grep -E "(prometheus|grafana|alertmanager|loki|promtail|alloy)" | awk '{print $1}' | xargs -r kubectl delete clusterrole --ignore-not-found 2>/dev/null || true
kubectl get clusterrolebindings | grep -E "(prometheus|grafana|alertmanager|loki|promtail|alloy)" | awk '{print $1}' | xargs -r kubectl delete clusterrolebinding --ignore-not-found 2>/dev/null || true
kubectl get crd | grep -E "(prometheus|grafana|alertmanager|servicemonitor|prometheusrule)" | awk '{print $1}' | xargs -r kubectl delete crd --ignore-not-found 2>/dev/null || true
print_success "Cluster-scoped resources cleaned up"

# 3. Clean up monitoring resources by labels
print_info "Cleaning up monitoring resources by labels..."
kubectl delete all -l app.kubernetes.io/name=grafana --namespace project 2>/dev/null || true
kubectl delete all -l app.kubernetes.io/name=prometheus --namespace project 2>/dev/null || true
kubectl delete all -l app.kubernetes.io/name=loki --namespace project 2>/dev/null || true
kubectl delete all -l app.kubernetes.io/name=grafana-alloy --namespace project 2>/dev/null || true
print_success "Monitoring resources cleaned up"

# 4. Clean up configmaps and secrets
print_info "Cleaning up configmaps and secrets..."
kubectl delete configmap -l app.kubernetes.io/name=grafana --namespace project 2>/dev/null || true
kubectl delete secret -l app.kubernetes.io/name=grafana --namespace project 2>/dev/null || true
kubectl delete configmap -l app.kubernetes.io/name=prometheus --namespace project 2>/dev/null || true
kubectl delete secret -l app.kubernetes.io/name=prometheus --namespace project 2>/dev/null || true
kubectl delete configmap -l app.kubernetes.io/name=loki --namespace project 2>/dev/null || true
kubectl delete configmap -l app.kubernetes.io/name=grafana-alloy --namespace project 2>/dev/null || true
print_success "ConfigMaps and secrets cleaned up"

# 4.5. Clean up Persistent Volume Claims and Volumes
print_info "Cleaning up Persistent Volume Claims and Volumes..."
kubectl delete pvc -l app.kubernetes.io/name=loki --namespace project 2>/dev/null || true
kubectl delete pvc -l app.kubernetes.io/name=promtail --namespace project 2>/dev/null || true
kubectl delete pv -l app.kubernetes.io/name=loki 2>/dev/null || true
kubectl delete pv -l app.kubernetes.io/name=promtail 2>/dev/null || true
print_success "PVCs and PVs cleaned up"

# 4.6. Clean up Service Accounts
print_info "Cleaning up Service Accounts..."
kubectl delete serviceaccount -l app.kubernetes.io/name=loki --namespace project 2>/dev/null || true
kubectl delete serviceaccount -l app.kubernetes.io/name=promtail --namespace project 2>/dev/null || true
print_success "Service Accounts cleaned up"

# 4.7. Clean up Network Policies
print_info "Cleaning up Network Policies..."
kubectl delete networkpolicy -l app.kubernetes.io/name=loki --namespace project 2>/dev/null || true
kubectl delete networkpolicy -l app.kubernetes.io/name=promtail --namespace project 2>/dev/null || true
print_success "Network Policies cleaned up"

# 4.8. Clean up Ingress Resources
print_info "Cleaning up Ingress Resources..."
kubectl delete ingress -l app.kubernetes.io/name=loki --namespace project 2>/dev/null || true
kubectl delete ingress -l app.kubernetes.io/name=promtail --namespace project 2>/dev/null || true
print_success "Ingress Resources cleaned up"

# 4.9. Clean up additional CRDs (Loki-specific)
print_info "Cleaning up additional CRDs..."
kubectl get crd | grep -E "(loki|promtail)" | awk '{print $1}' | xargs -r kubectl delete crd --ignore-not-found 2>/dev/null || true
print_success "Additional CRDs cleaned up"

# 5. Kill any port-forward processes
print_info "Stopping port-forward processes..."
pkill -f "kubectl.*port-forward.*3000" 2>/dev/null && print_success "Grafana port-forwards stopped" || print_warning "No Grafana port-forwards found"
pkill -f "kubectl.*port-forward.*9090" 2>/dev/null && print_success "Prometheus port-forwards stopped" || print_warning "No Prometheus port-forwards found"
pkill -f "kubectl.*port-forward.*3100" 2>/dev/null && print_success "Loki port-forwards stopped" || print_warning "No Loki port-forwards found"

# 6. Wait for cleanup to complete
print_info "Waiting for cleanup to complete..."
sleep 5

# 7. Verify clean state
print_info "Verifying clean state..."
echo ""
print_info "Remaining resources in project namespace:"
kubectl get all --namespace project 2>/dev/null || print_warning "No resources found (this is good!)"

echo ""
print_info "Remaining Helm releases:"
helm list --namespace project 2>/dev/null || print_warning "No Helm releases found (this is good!)"

echo ""
print_info "Remaining ConfigMaps:"
kubectl get configmap --namespace project 2>/dev/null || print_warning "No ConfigMaps found (this is good!)"

echo ""
print_info "Remaining Secrets:"
kubectl get secret --namespace project 2>/dev/null || print_warning "No Secrets found (this is good!)"

echo ""
print_success "🎉 Complete cleanup finished!"
print_info "You now have a clean slate to start fresh with monitoring setup."
echo ""
print_info "Next steps:"
print_info "1. Run: chmod +x scripts/remove_monitoring_env.sh"
print_info "2. Run: ./scripts/remove_monitoring_env.sh"
print_info "3. Start with Step 1: Grafana + Prometheus"