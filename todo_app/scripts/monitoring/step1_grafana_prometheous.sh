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
NAMESPACE="${NAMESPACE:-project}"

# 1. Add Helm repositories
print_info "Adding Helm repositories..."
if ! helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null; then
    print_info "Repository already exists, updating..."
fi
if ! helm repo update; then
    print_error "Failed to update Helm repositories"
    exit 1
fi
print_success "Helm repositories added and updated"

# 2. Fix ClusterRole and ClusterRoleBinding conflicts from previous installations
print_info "Checking for ClusterRole conflicts..."
CONFLICTING_CLUSTER_ROLES=(
    "prometheus-stack-grafana-clusterrole"
    "prometheus-stack-kube-state-metrics"
    "prometheus-stack-operator"
    "prometheus-stack-prometheus-operator"
)

for CLUSTER_ROLE in "${CONFLICTING_CLUSTER_ROLES[@]}"; do
    if kubectl get clusterrole "$CLUSTER_ROLE" >/dev/null 2>&1; then
        CLUSTER_ROLE_NAMESPACE=$(kubectl get clusterrole "$CLUSTER_ROLE" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || echo "")
        if [ -n "${CLUSTER_ROLE_NAMESPACE}" ] && [ "${CLUSTER_ROLE_NAMESPACE}" != "${NAMESPACE}" ]; then
            print_warning "ClusterRole '$CLUSTER_ROLE' exists from namespace '${CLUSTER_ROLE_NAMESPACE}'"
            print_info "Deleting old ClusterRole to avoid conflict..."
            kubectl delete clusterrole "$CLUSTER_ROLE" || true
            print_success "Old ClusterRole deleted"
        fi
    fi
done

# Check for ClusterRoleBindings
CONFLICTING_CLUSTER_ROLE_BINDINGS=(
    "prometheus-stack-grafana-clusterrolebinding"
    "prometheus-stack-kube-state-metrics"
    "prometheus-stack-operator"
    "prometheus-stack-prometheus-operator"
)

for CLUSTER_ROLE_BINDING in "${CONFLICTING_CLUSTER_ROLE_BINDINGS[@]}"; do
    if kubectl get clusterrolebinding "$CLUSTER_ROLE_BINDING" >/dev/null 2>&1; then
        CLUSTER_ROLE_BINDING_NAMESPACE=$(kubectl get clusterrolebinding "$CLUSTER_ROLE_BINDING" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || echo "")
        if [ -n "${CLUSTER_ROLE_BINDING_NAMESPACE}" ] && [ "${CLUSTER_ROLE_BINDING_NAMESPACE}" != "${NAMESPACE}" ]; then
            print_warning "ClusterRoleBinding '$CLUSTER_ROLE_BINDING' exists from namespace '${CLUSTER_ROLE_BINDING_NAMESPACE}'"
            print_info "Deleting old ClusterRoleBinding to avoid conflict..."
            kubectl delete clusterrolebinding "$CLUSTER_ROLE_BINDING" || true
            print_success "Old ClusterRoleBinding deleted"
        fi
    fi
done

# 3. Clean up webhook configurations from previous installations
print_info "Checking for webhook configuration conflicts..."
if command -v jq >/dev/null 2>&1; then
    WEBHOOK_RESOURCES=$(kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration -o json 2>/dev/null | \
        jq -r --arg ns "${NAMESPACE}" '.items[] | 
        select(.metadata.annotations."meta.helm.sh/release-namespace" != null) |
        select(.metadata.annotations."meta.helm.sh/release-namespace" != $ns) |
        select(.metadata.annotations."meta.helm.sh/release-namespace" != "") |
        "\(.kind)/\(.metadata.name)"' 2>/dev/null || echo "")
    
    if [ -n "$WEBHOOK_RESOURCES" ]; then
        print_warning "Found webhook configurations from other namespaces"
        echo "$WEBHOOK_RESOURCES" | while read -r resource; do
            if [ -n "$resource" ]; then
                kind=$(echo "$resource" | cut -d'/' -f1)
                name=$(echo "$resource" | cut -d'/' -f2)
                print_info "Deleting $kind/$name..."
                kubectl delete "$kind" "$name" 2>/dev/null || true
            fi
        done
        print_success "Webhook configurations cleaned up"
    fi
else
    # Fallback: delete known prometheus-stack webhook configurations
    for webhook in prometheus-stack-kube-prom-admission; do
        if kubectl get mutatingwebhookconfiguration "$webhook" >/dev/null 2>&1; then
            WEBHOOK_NS=$(kubectl get mutatingwebhookconfiguration "$webhook" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || echo "")
            if [ -n "${WEBHOOK_NS}" ] && [ "${WEBHOOK_NS}" != "${NAMESPACE}" ]; then
                print_info "Deleting MutatingWebhookConfiguration $webhook..."
                kubectl delete mutatingwebhookconfiguration "$webhook" 2>/dev/null || true
            fi
        fi
        if kubectl get validatingwebhookconfiguration "$webhook" >/dev/null 2>&1; then
            WEBHOOK_NS=$(kubectl get validatingwebhookconfiguration "$webhook" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || echo "")
            if [ -n "${WEBHOOK_NS}" ] && [ "${WEBHOOK_NS}" != "${NAMESPACE}" ]; then
                print_info "Deleting ValidatingWebhookConfiguration $webhook..."
                kubectl delete validatingwebhookconfiguration "$webhook" 2>/dev/null || true
            fi
        fi
    done
fi

# 4. Clean up kube-system resources from previous installations
print_info "Checking for monitoring resources in kube-system namespace..."
if command -v jq >/dev/null 2>&1; then
    KUBE_SYSTEM_RESOURCES=$(kubectl get all,configmap,secret,serviceaccount,servicemonitor -n kube-system -o json 2>/dev/null | \
        jq -r --arg ns "${NAMESPACE}" '.items[] | 
        select(.metadata.annotations."meta.helm.sh/release-namespace" != null) |
        select(.metadata.annotations."meta.helm.sh/release-namespace" != $ns) |
        select(.metadata.annotations."meta.helm.sh/release-namespace" != "") |
        "\(.kind)/\(.metadata.name)"' 2>/dev/null || echo "")
    
    if [ -n "$KUBE_SYSTEM_RESOURCES" ]; then
        print_warning "Found monitoring resources in kube-system from other namespaces"
        echo "$KUBE_SYSTEM_RESOURCES" | while read -r resource; do
            if [ -n "$resource" ]; then
                kind=$(echo "$resource" | cut -d'/' -f1)
                name=$(echo "$resource" | cut -d'/' -f2)
                print_info "Deleting $kind/$name from kube-system..."
                kubectl delete "$kind" "$name" -n kube-system 2>/dev/null || true
            fi
        done
        print_success "kube-system resources cleaned up"
    else
        print_info "No conflicting resources found in kube-system"
    fi
else
    # Fallback: delete known prometheus-stack services in kube-system
    print_warning "jq not found, using fallback method to clean kube-system..."
    for svc in prometheus-stack-kube-prom-coredns prometheus-stack-kube-prom-kube-controller-manager \
               prometheus-stack-kube-prom-kube-etcd prometheus-stack-kube-prom-kube-proxy \
               prometheus-stack-kube-prom-kube-scheduler prometheus-stack-kube-prom-kubelet; do
        if kubectl get svc "$svc" -n kube-system >/dev/null 2>&1; then
            SVC_NS=$(kubectl get svc "$svc" -n kube-system -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || echo "")
            if [ -n "${SVC_NS}" ] && [ "${SVC_NS}" != "${NAMESPACE}" ]; then
                print_info "Deleting service $svc from kube-system..."
                kubectl delete svc "$svc" -n kube-system 2>/dev/null || true
            fi
        fi
    done
fi

# 5. Check if already installed
if helm list --namespace "${NAMESPACE}" | grep -q prometheus-stack; then
    print_warning "Prometheus stack already installed, upgrading..."
    helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack --namespace "${NAMESPACE}" \
      --set grafana.adminPassword=admin123 \
      --set grafana.service.type=ClusterIP \
      --set grafana.persistence.enabled=true \
      --set grafana.persistence.size=1Gi \
      --set prometheus.prometheusSpec.retention=7d \
      --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi
    INSTALL_RESULT=$?
else
    print_info "Installing Prometheus + Grafana stack in namespace: ${NAMESPACE}..."
    helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace "${NAMESPACE}" \
      --set grafana.adminPassword=admin123 \
      --set grafana.service.type=ClusterIP \
      --set grafana.persistence.enabled=true \
      --set grafana.persistence.size=1Gi \
      --set prometheus.prometheusSpec.retention=7d \
      --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
      --create-namespace
    INSTALL_RESULT=$?
fi

if [ ${INSTALL_RESULT} -eq 0 ]; then 
    print_success "Prometheus + Grafana stack installed/upgraded successfully"
else
    print_error "Failed to install/upgrade Prometheus + Grafana stack"
    exit 1
fi

# 6. Wait for pods to be ready
print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --namespace "${NAMESPACE}" --timeout=5m || {
    print_warning "Grafana pods may not be ready yet"
}
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus --namespace "${NAMESPACE}" --timeout=5m || {
    print_warning "Prometheus pods may not be ready yet"
}
print_success "Waiting for pods complete"

# 7. Services are automatically created by Helm
print_info "Services are automatically created by Helm chart"
print_success "Grafana service: prometheus-stack-grafana"
print_success "Prometheus service: prometheus-stack-kube-prom-prometheus"

# 8. Show status
print_info "Current status:"
kubectl get pods --namespace "${NAMESPACE}" -l "app.kubernetes.io/name in (grafana,prometheus)"
kubectl get services --namespace "${NAMESPACE}" -l "app.kubernetes.io/name in (grafana,prometheus)"

# 9. Show access information
echo ""
print_success "🎉 Step 1 Complete: Grafana + Prometheus installed!"
echo ""
print_info "📊 Access Information:"
print_info "  Grafana:"
print_info "    kubectl -n ${NAMESPACE} port-forward svc/prometheus-stack-grafana 3000:80"
print_info "    Then visit: http://localhost:3000 (admin/admin123)"
print_info ""
print_info "  Prometheus:"
print_info "    kubectl -n ${NAMESPACE} port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090"
print_info "    Then visit: http://localhost:9090"
echo ""
print_info "📋 What's included:"
print_info "  ✅ Prometheus (metrics collection)"
print_info "  ✅ Grafana (visualization)"
print_info "  ✅ Pre-configured dashboards"
print_info "  ✅ Kubernetes cluster metrics"
print_info "  ✅ AlertManager (for alerts)"
echo ""
print_info "🎯 Next step: Run step2_grafana_alloy_loki.sh to add log collection"