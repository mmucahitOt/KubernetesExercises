#!/bin/bash

# !!! IMPORTANT !!!
# The user should be logged in to Docker Hub before running this script
# docker login

# ============================================================================
# DESCRIPTION
# ============================================================================
# This script deploys the todo_app application to a Kubernetes cluster
# using Kustomize. It follows a hybrid approach:
#   - Helm charts for monitoring (Prometheus/Grafana/Alloy)
#   - Kustomize for application manifests

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
# Docker registry from command line argument
DOCKER_REGISTRY="${1:-}"
if [ -z "${DOCKER_REGISTRY}" ]; then
    print_error "Usage: $0 <docker-registry>"
    print_info "Example: $0 mmucahit0"
    exit 1
fi

# Application configuration (used by Kustomize configMapGenerator)
export TODO_APP_PORT=4000
export TODO_APP_BACKEND_PORT=4001
export TODO_APP_BACKEND_DB_URL="postgres://todo_user:todo_password@localhost:5432/todo_db"
export RANDOM_IMAGE_PATH="/app/files/image.jpeg"

# Monitoring configuration
MONITORING_SCRIPTS="${MONITORING_SCRIPTS:-false}"

# Kubernetes cluster configuration
CLUSTER_NAME="k3d-k3s-default"
NAMESPACE="project"

# Docker images configuration (avoid associative arrays for macOS bash 3.2)
IMAGE_TODO_APP="todo_app:amd64-v1"
IMAGE_TODO_BACKEND="todo_app_backend:amd64-v1"
IMAGE_TODO_BACKEND_DB="todo_app_backend_db:amd64-v1"
IMAGE_TODO_ADD_JOB="todo_app_add_job:amd64-v1"
IMAGE_TODO_BACKUP_JOB="todo_app_backup_job:amd64-v1" 

# ============================================================================
# DIRECTORY RESOLUTION
# ============================================================================
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
TODO_APP_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
TODO_APP_DIR="${TODO_APP_ROOT}/todo_app"
TODO_APP_BACKEND_DIR="${TODO_APP_ROOT}/todo_app_backend"
TODO_APP_BACKEND_DB_DIR="${TODO_APP_ROOT}/todo_app_backend_db"
TODO_APP_ADD_JOB_DIR="${TODO_APP_ROOT}/todo_app_add_job"
TODO_APP_BACKUP_JOB_DIR="${TODO_APP_ROOT}/todo_app_db_backup_cronjob"
FRONTEND_DIR="${TODO_APP_ROOT}/todo_app_frontend"
FRONTEND_DIST_DIR="${FRONTEND_DIR}/dist"
TODO_PUBLIC_DIR="${TODO_APP_DIR}/public"
MONITORING_DIR="${TODO_APP_ROOT}/scripts/monitoring"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
build_and_push_image() {
    local image_name=$1
    local dockerfile_dir=$2
    local registry_tag="${DOCKER_REGISTRY}/${image_name}"
    
    print_info "Building ${image_name} for linux/amd64 (Buildx, no cache)..."
    # Build a linux/amd64 image and load into local Docker (for k3d import/debug)
    if ! docker buildx build --platform linux/amd64 --no-cache -t "${image_name}" "${dockerfile_dir}" --load; then
        print_error "Failed to build ${image_name} (linux/amd64)"
        return 1
    fi
    print_success "${image_name} (linux/amd64) built and loaded locally"
    
    print_info "Tagging ${registry_tag}..."
    docker tag "${image_name}" "${registry_tag}"
    
    print_info "Pushing ${registry_tag}..."
    if ! docker push "${registry_tag}"; then
        print_error "Failed to push ${registry_tag}"
        return 1
    fi
    print_success "${registry_tag} pushed"
    
    return 0
}

import_images_to_k3d() {
    print_info "Importing images into k3d cluster to ensure amd64-v1 versions are used..."
    for image_name in \
        "${IMAGE_TODO_APP}" \
        "${IMAGE_TODO_BACKEND}" \
        "${IMAGE_TODO_BACKEND_DB}" \
        "${IMAGE_TODO_ADD_JOB}"; do
        registry_tag="${DOCKER_REGISTRY}/${image_name}"
        # Import both local and registry-tagged images
        k3d image import "${image_name}" -c "${CLUSTER_NAME}" 2>/dev/null || true
        k3d image import "${registry_tag}" -c "${CLUSTER_NAME}" 2>/dev/null || true
    done
    print_success "Images imported into k3d cluster"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
print_header "🚀 TODO APP DEPLOYMENT"
print_info "Docker Registry: ${DOCKER_REGISTRY}"
print_info "Monitoring Scripts: ${MONITORING_SCRIPTS}"

# ----------------------------------------------------------------------------
# FRONTEND BUILD
# ----------------------------------------------------------------------------
print_header "🎨 BUILDING FRONTEND"
if [ -d "${FRONTEND_DIR}" ]; then
    pushd "${FRONTEND_DIR}" >/dev/null || exit 1
    
    print_info "Setting environment variables for frontend..."
    # Frontend is served via ingress at localhost:300
    # Backend API is at /todos path on the same domain
    # Note: backendApiUrl will have /todos appended in the service, so use base URL
    export VITE_TODO_API_URL="http://localhost:8081"
    export VITE_TODO_BACKEND_API_URL="http://localhost:8081"
    print_success "Environment variables set"
    print_info "  VITE_TODO_API_URL=${VITE_TODO_API_URL}"
    print_info "  VITE_TODO_BACKEND_API_URL=${VITE_TODO_BACKEND_API_URL}"
    
    if command -v npm >/dev/null 2>&1; then
        print_info "Installing dependencies..."
        npm ci || npm install
        print_success "Dependencies installed"
        
        print_info "Building frontend with environment variables..."
        # Ensure environment variables are available during build
        npm run build
        print_success "Frontend built successfully"
    else
        print_error "npm is not installed; cannot build frontend"
        exit 1
    fi
    
    popd >/dev/null || exit 1
    
    print_info "Copying frontend dist to backend public..."
    mkdir -p "${TODO_PUBLIC_DIR}"
    rm -rf "${TODO_PUBLIC_DIR}/"*
    cp -R "${FRONTEND_DIST_DIR}/." "${TODO_PUBLIC_DIR}/"
    print_success "Frontend files copied to backend"
else
    print_warning "Frontend directory not found at ${FRONTEND_DIR}; skipping frontend build"
fi

# ----------------------------------------------------------------------------
# DOCKER BUILD & PUSH
# ----------------------------------------------------------------------------
print_header "🐳 BUILDING & PUSHING DOCKER IMAGES"

# Build and push each image explicitly (portable across shells)
build_and_push_image "${IMAGE_TODO_APP}" "${TODO_APP_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_BACKEND}" "${TODO_APP_BACKEND_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_BACKEND_DB}" "${TODO_APP_BACKEND_DB_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_ADD_JOB}" "${TODO_APP_ADD_JOB_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_BACKUP_JOB}" "${TODO_APP_BACKUP_JOB_DIR}" || exit 1
# ----------------------------------------------------------------------------
# KUBERNETES CLUSTER SETUP
# ----------------------------------------------------------------------------
print_header "☸️  KUBERNETES CLUSTER SETUP"

print_info "Cluster information:"
kubectl cluster-info

print_info "Starting cluster..."
k3d cluster start || true
print_success "Cluster started successfully"

# ----------------------------------------------------------------------------
# PERSISTENT STORAGE SETUP
# ----------------------------------------------------------------------------
print_header "💾 SETTING UP PERSISTENT STORAGE"
print_info "Creating storage directory on node..."
docker exec "${CLUSTER_NAME}-agent-0" mkdir -p /tmp/kube || true
print_success "Storage directory created"

# ----------------------------------------------------------------------------
# NAMESPACE SETUP
# ----------------------------------------------------------------------------
print_header "📁 NAMESPACE SETUP"
print_info "Namespace will be created by Kustomize"
print_info "Setting namespace context for kubectl commands..."
kubens "${NAMESPACE}" || true  # Allow failure if namespace doesn't exist yet (Kustomize will create it)
print_success "Namespace context configured"

# ----------------------------------------------------------------------------
# MONITORING SETUP (Hybrid Approach: Helm Charts)
# ----------------------------------------------------------------------------
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
    print_info "MONITORING_SCRIPTS=false → monitoring manifests applied via Kustomize; skipping scripts"
fi

# ----------------------------------------------------------------------------
# KUSTOMIZE DEPLOYMENT
# ----------------------------------------------------------------------------
print_header "🧩 KUSTOMIZE DEPLOYMENT"

# Update Kustomize image references
if command -v kustomize >/dev/null 2>&1; then
    print_info "Setting Kustomize image overrides..."
    pushd "${TODO_APP_ROOT}" >/dev/null || exit 1
    kustomize edit set image "TODO_APP_IMAGE/TAG=${DOCKER_REGISTRY}/todo_app:amd64-v1"
    kustomize edit set image "TODO_APP_BACKEND_IMAGE/TAG=${DOCKER_REGISTRY}/todo_app_backend:amd64-v1"
    kustomize edit set image "TODO_APP_BACKEND_DB_IMAGE/TAG=${DOCKER_REGISTRY}/todo_app_backend_db:amd64-v1"
    kustomize edit set image "TODO_APP_ADD_JOB_IMAGE/TAG=${DOCKER_REGISTRY}/todo_app_add_job:amd64-v1"
    kustomize edit set image "TODO_APP_BACKUP_JOB_IMAGE/TAG=${DOCKER_REGISTRY}/todo_app_backup_job:amd64-v1"
    popd >/dev/null || exit 1
    print_success "Kustomize images updated"
else
    print_warning "kustomize not installed; using images declared in kustomize.yaml"
fi

# Import images into k3d cluster before applying manifests
print_info "Importing images into k3d cluster..."
import_images_to_k3d

# Apply Kustomize manifests
print_info "Applying Kustomize manifests..."
if ! kubectl apply -k "${TODO_APP_ROOT}"; then
    print_error "Failed to apply Kustomize manifests"
    exit 1
fi
print_success "Kustomize apply complete"

# Force pod restart to use new images
print_info "Restarting pods to use new images..."
kubectl rollout restart statefulset/todo-app-stset --namespace="${NAMESPACE}" || {
    print_warning "Failed to restart StatefulSet (may not exist yet)"
}

# ----------------------------------------------------------------------------
# WAIT FOR DEPLOYMENT
# ----------------------------------------------------------------------------
print_header "⏳ WAITING FOR DEPLOYMENT"
print_info "Waiting for StatefulSet to be available..."
kubectl rollout status statefulset/todo-app-stset --namespace="${NAMESPACE}" --timeout=300s || {
    print_warning "StatefulSet rollout may not be complete"
}

kubectl wait --for=condition=available statefulset/todo-app-stset --namespace="${NAMESPACE}" --timeout=300s || {
    print_warning "StatefulSet may not be available yet"
}

print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=todo-app-stset --namespace="${NAMESPACE}" --timeout=60s || {
    print_warning "Some pods may not be ready yet"
}

# ----------------------------------------------------------------------------
# DEPLOYMENT STATUS
# ----------------------------------------------------------------------------
print_header "📊 DEPLOYMENT STATUS"
print_info "StatefulSets:"
kubectl get statefulsets --namespace="${NAMESPACE}"

print_info "Pods:"
kubectl get pods --namespace="${NAMESPACE}"

# ----------------------------------------------------------------------------
# APPLICATION LOGS
# ----------------------------------------------------------------------------
print_header "📝 APPLICATION LOGS"
kubectl logs statefulset/todo-app-stset --namespace="${NAMESPACE}" --all-containers --tail=50 || {
    print_warning "Could not retrieve logs"
}

# ----------------------------------------------------------------------------
# DEPLOYMENT COMPLETE
# ----------------------------------------------------------------------------
print_header "🎉 DEPLOYMENT COMPLETE"
print_success "Todo app deployed successfully!"
print_info "Your todo application is now running in Kubernetes"

# ----------------------------------------------------------------------------
# HELPFUL COMMANDS
# ----------------------------------------------------------------------------
print_header "🔧 HELPFUL COMMANDS"
cat << EOF
${CYAN}Application Access:${NC}
  🌐 Frontend: http://localhost:8081
  🔧 Backend API: http://localhost:8081/todos

${CYAN}Monitoring Access:${NC}
  📊 Grafana:
    kubectl -n ${NAMESPACE} port-forward \$(kubectl -n ${NAMESPACE} get pods -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus-stack -o jsonpath='{.items[0].metadata.name}') 3000:3000
    Then visit: http://localhost:3000 (admin/admin123)

  📈 Prometheus:
    kubectl -n ${NAMESPACE} port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090
    Then visit: http://localhost:9090

  📝 Loki:
    kubectl -n ${NAMESPACE} port-forward svc/loki 3100:3100
    Then visit: http://localhost:3100

${CYAN}Debugging:${NC}
  View pods: kubectl -n ${NAMESPACE} get pods
  View logs: kubectl -n ${NAMESPACE} logs -l app=todo-app-stset --tail=50
  Check status: kubectl -n ${NAMESPACE} get all

${CYAN}Port-forward Management:${NC}
  Check: lsof -i :3000
  Kill: pkill -f 'kubectl.*port-forward'
EOF
