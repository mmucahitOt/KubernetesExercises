#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
TODO_APP_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
ARGOCD_APP_PATH="${TODO_APP_ROOT}/argocd/applications/todo-app.yaml"

print_header "🚀 ARGOCD INSTALLATION AND DEPLOYMENT FOR GKE"

print_info "Checking kubectl connection..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "kubectl is not configured or cluster is not accessible"
    print_info "Please run: gcloud container clusters get-credentials <cluster-name> --zone <zone> --project <project-id>"
    exit 1
fi
print_success "kubectl is configured"

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "unknown")
print_info "Connected to cluster: ${CLUSTER_NAME}"

print_header "📦 INSTALLING ARGOCD"
print_info "Checking if ArgoCD is already installed..."
if kubectl get namespace argocd >/dev/null 2>&1 && kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    print_success "ArgoCD is already installed"
    print_info "Skipping ArgoCD installation"
else
    print_info "Creating argocd namespace..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace created"
    
    print_info "Installing ArgoCD..."
    if kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml; then
        print_success "ArgoCD installation manifest applied"
    else
        print_error "Failed to apply ArgoCD installation manifest"
        exit 1
    fi
    
    print_header "⏳ WAITING FOR ARGOCD TO BE READY"
    print_info "Waiting for ArgoCD server deployment..."
    if kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd; then
        print_success "ArgoCD server is ready"
    else
        print_warning "ArgoCD server deployment timeout. It may still be starting up."
        print_info "You can check status with: kubectl get pods -n argocd"
    fi
    
    print_info "Waiting for ArgoCD application controller..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-applicationset-controller -n argocd || true
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd || true
fi

print_header "🔑 ARGOCD ADMIN CREDENTIALS"
print_info "Retrieving ArgoCD admin password..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ -z "$ADMIN_PASSWORD" ]; then
    print_warning "Admin password not found. ArgoCD may still be initializing."
    print_info "You can retrieve it later with:"
    print_info "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
else
    print_success "Admin password retrieved"
    echo ""
    echo -e "${WHITE}ArgoCD Admin Credentials:${NC}"
    echo -e "  ${CYAN}Username:${NC} admin"
    echo -e "  ${CYAN}Password:${NC} ${ADMIN_PASSWORD}"
    echo ""
fi

print_header "🌐 ARGOCD ACCESS INFORMATION"
print_info "To access ArgoCD UI, you can use one of the following methods:"
echo ""
echo -e "${CYAN}Option 1: Port-forward (recommended for local access)${NC}"
echo -e "  ${WHITE}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
echo -e "  Then visit: ${GREEN}https://localhost:8080${NC}"
echo ""
echo -e "${CYAN}Option 2: LoadBalancer (for external access)${NC}"
echo -e "  ${WHITE}kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'${NC}"
echo -e "  ${WHITE}kubectl get svc argocd-server -n argocd${NC}"
echo ""

print_header "📋 APPLYING ARGOCD APPLICATION"
if [ ! -f "${ARGOCD_APP_PATH}" ]; then
    print_error "ArgoCD Application manifest not found: ${ARGOCD_APP_PATH}"
    exit 1
fi

print_info "Checking if Git repository URL is configured..."
if grep -q "YOUR_USERNAME\|YOUR_REPO" "${ARGOCD_APP_PATH}"; then
    print_warning "Git repository URL needs to be updated in the ArgoCD Application manifest"
    print_info "Please update: ${ARGOCD_APP_PATH}"
    print_info "Change: repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git"
    print_info "To: repoURL: https://github.com/<your-username>/<your-repo>.git"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Exiting. Please update the manifest and run again."
        exit 0
    fi
fi

print_info "Applying ArgoCD Application manifest..."
if kubectl apply -f "${ARGOCD_APP_PATH}"; then
    print_success "ArgoCD Application applied"
else
    print_error "Failed to apply ArgoCD Application"
    exit 1
fi

print_header "⏳ WAITING FOR APPLICATION SYNC"
print_info "Waiting for ArgoCD Application to be created..."
sleep 5

if kubectl get application todo-app -n argocd >/dev/null 2>&1; then
    print_success "ArgoCD Application created"
    
    print_info "Application status:"
    kubectl get application todo-app -n argocd
    
    print_info "Waiting for initial sync (this may take a few minutes)..."
    print_info "You can check status with: kubectl get application todo-app -n argocd -o yaml"
    
    SYNC_TIMEOUT=300
    ELAPSED=0
    while [ $ELAPSED -lt $SYNC_TIMEOUT ]; do
        SYNC_STATUS=$(kubectl get application todo-app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        HEALTH_STATUS=$(kubectl get application todo-app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        if [ "$SYNC_STATUS" = "Synced" ] && [ "$HEALTH_STATUS" = "Healthy" ]; then
            print_success "Application synced and healthy!"
            break
        fi
        
        if [ "$SYNC_STATUS" = "Unknown" ]; then
            print_info "Waiting for ArgoCD to process application... (${ELAPSED}s/${SYNC_TIMEOUT}s)"
        else
            print_info "Sync status: ${SYNC_STATUS}, Health: ${HEALTH_STATUS} (${ELAPSED}s/${SYNC_TIMEOUT}s)"
        fi
        
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    if [ $ELAPSED -ge $SYNC_TIMEOUT ]; then
        print_warning "Sync timeout reached. Application may still be syncing."
        print_info "Check status manually: kubectl get application todo-app -n argocd"
    fi
else
    print_warning "ArgoCD Application not found. It may take a moment to appear."
    print_info "Check with: kubectl get applications -n argocd"
fi

print_header "📊 DEPLOYMENT STATUS"
print_info "ArgoCD Applications:"
kubectl get applications -n argocd || true

print_info "Resources in project namespace:"
kubectl get all -n project || print_warning "No resources found in project namespace yet"

print_header "✅ INSTALLATION COMPLETE"
print_success "ArgoCD has been installed and configured!"
echo ""
print_info "Next steps:"
echo -e "  1. ${CYAN}Access ArgoCD UI${NC} (see access information above)"
echo -e "  2. ${CYAN}Check application status${NC}: kubectl get application todo-app -n argocd"
echo -e "  3. ${CYAN}View application details${NC}: kubectl describe application todo-app -n argocd"
echo -e "  4. ${CYAN}Check deployed resources${NC}: kubectl get all -n project"
echo ""
print_info "If the Git repository URL needs to be updated, edit:"
print_info "  ${ARGOCD_APP_PATH}"
print_info "Then run: kubectl apply -f ${ARGOCD_APP_PATH}"
echo ""

