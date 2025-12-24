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
#
# Supported Clusters:
#   - GKE (Google Kubernetes Engine) - fully supported
#   - k3d (local development) - fully supported
#   - Other Kubernetes clusters (EKS, AKS, etc.) - should work
#
# ============================================================================
# SCRIPT ARGUMENTS
# ============================================================================
# Usage: ./kubernetes_deploy_with_kustomize.sh <docker-registry> [build_images]
#
# Arguments:
#   1. docker-registry (REQUIRED)
#      - Docker registry username or registry URL
#      - Images will be tagged as: <docker-registry>/<image-name>:<tag>
#      - Example: "mmucahit0" or "gcr.io/my-project"
#
#   2. build_images (OPTIONAL, default: true)
#      - Controls whether to build and push Docker images
#      - Accepts: true, false, yes, no, 1, 0, skip
#      - If false/skip: Uses existing images in registry (faster for re-deployments)
#      - If true: Builds all 5 images (todo_app, todo_app_backend, etc.)
#      - Example: "./kubernetes_deploy_with_kustomize.sh mmucahit0 false"
#
# Environment Variables:
#   - MONITORING_SCRIPTS: Controls monitoring setup approach
#     - Set to "true" or unset (default): Runs Helm-based monitoring setup scripts
#       * Installs Prometheus + Grafana stack via Helm
#       * Installs Grafana Alloy + Loki via Helm
#       * Configures Grafana data sources
#       * Use this for full monitoring stack with Helm charts
#     - Set to "false": Uses Kustomize manifests only
#       * Applies monitoring manifests from kustomization.yaml
#       * Simpler, faster deployment
#       * Example: export MONITORING_SCRIPTS=false
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
# Docker registry from command line argument
DOCKER_REGISTRY="${1:-}"
if [ -z "${DOCKER_REGISTRY}" ]; then
    print_error "Usage: $0 <docker-registry> [build_images=true|false]"
    print_info "Example: $0 mmucahit0 true"
    exit 1
fi

# Optional arg to control Docker image build & push (default: true)
BUILD_IMAGES_RAW="${2:-true}"
# Normalize to lowercase
BUILD_IMAGES="$(printf '%s' "${BUILD_IMAGES_RAW}" | tr '[:upper:]' '[:lower:]')"
# Interpret common falsy values
if [[ "${BUILD_IMAGES}" == "0" || "${BUILD_IMAGES}" == "false" || "${BUILD_IMAGES}" == "no" || "${BUILD_IMAGES}" == "skip" ]]; then
    BUILD_IMAGES="false"
else
    BUILD_IMAGES="true"
fi

# Application configuration (used by Kustomize configMapGenerator)
export TODO_APP_PORT=4000
export TODO_APP_BACKEND_PORT=4001
export TODO_APP_BACKEND_DB_URL="postgres://todo_user:todo_password@localhost:5432/todo_db"
export RANDOM_IMAGE_PATH="/app/files/image.jpeg"

# Monitoring configuration
MONITORING_SCRIPTS="${MONITORING_SCRIPTS:-true}"

# Kubernetes cluster configuration
# CLUSTER_NAME is only used for k3d clusters (for image import, storage setup)
# For GKE or other clusters, this is ignored
CLUSTER_NAME="${K3D_CLUSTER_NAME:-k3d-k3s-default}"
NAMESPACE="project"

# Docker images configuration (avoid associative arrays for macOS bash 3.2)
IMAGE_TODO_APP="todo_app:amd64-v1"
IMAGE_TODO_BACKEND="todo_app_backend:amd64-v1"
IMAGE_TODO_BACKEND_DB="todo_app_backend_db:amd64-v1"
IMAGE_TODO_ADD_JOB="todo_app_add_job:amd64-v1"
IMAGE_TODO_BACKUP_JOB="todo_app_backup_job:amd64-v1" 
IMAGE_TODO_BROADCASTER="todo_app_broadcaster:amd64-v1"

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
        "${IMAGE_TODO_ADD_JOB}" \
        "${IMAGE_TODO_BROADCASTER}" \
        "${IMAGE_TODO_BACKUP_JOB}"; do
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
print_info "Build & Push Docker Images: ${BUILD_IMAGES}"

# ----------------------------------------------------------------------------
# FRONTEND BUILD
# ----------------------------------------------------------------------------
print_header "🎨 BUILDING FRONTEND"
if [ -d "${FRONTEND_DIR}" ]; then
    pushd "${FRONTEND_DIR}" >/dev/null || exit 1
    
    print_info "Building frontend with relative paths..."
    # Frontend uses relative paths that work with Ingress routing:
    #   / -> frontend service (todo-app-svc)
    #   /todos -> backend service (todo-app-backend-svc)
    # No need to set VITE_TODO_API_URL or VITE_TODO_BACKEND_API_URL
    # The frontend will use relative paths that work regardless of Ingress IP
    print_success "Frontend will use relative paths for API calls"
    
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
if [[ "${BUILD_IMAGES}" == "true" ]]; then
    print_header "🐳 BUILDING & PUSHING DOCKER IMAGES"
    # Build and push each image explicitly (portable across shells)
    build_and_push_image "${IMAGE_TODO_APP}" "${TODO_APP_DIR}" || exit 1
    build_and_push_image "${IMAGE_TODO_BACKEND}" "${TODO_APP_BACKEND_DIR}" || exit 1
    build_and_push_image "${IMAGE_TODO_BACKEND_DB}" "${TODO_APP_BACKEND_DB_DIR}" || exit 1
    build_and_push_image "${IMAGE_TODO_ADD_JOB}" "${TODO_APP_ADD_JOB_DIR}" || exit 1
    build_and_push_image "${IMAGE_TODO_BACKUP_JOB}" "${TODO_APP_BACKUP_JOB_DIR}" || exit 1
    build_and_push_image "${IMAGE_TODO_BROADCASTER}" "${TODO_APP_ROOT}/todo_app_broadcaster" || exit 1
else
    print_header "🐳 SKIPPING DOCKER BUILD & PUSH (per flag)"
    print_info "Using existing images in registry: ${DOCKER_REGISTRY}"
fi
# ----------------------------------------------------------------------------
# KUBERNETES CLUSTER SETUP
# ----------------------------------------------------------------------------
print_header "☸️  KUBERNETES CLUSTER SETUP"

print_info "Cluster information:"
kubectl cluster-info

# Detect cluster type
IS_K3D=false
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
# PERSISTENT STORAGE SETUP
# ----------------------------------------------------------------------------
print_header "💾 SETTING UP PERSISTENT STORAGE"
# Only setup storage for k3d clusters
if [ "${IS_K3D}" = "true" ]; then
    print_info "Creating storage directory on k3d node..."
    docker exec "${CLUSTER_NAME}-agent-0" mkdir -p /tmp/kube || true
    print_success "Storage directory created"
else
    print_info "Skipping storage setup (GKE uses persistent volumes - no manual setup needed)"
fi

# ----------------------------------------------------------------------------
# NAMESPACE SETUP
# ----------------------------------------------------------------------------
print_header "📁 NAMESPACE SETUP"
print_info "Namespace will be created by Kustomize"
print_info "Setting namespace context for kubectl commands..."
kubens "${NAMESPACE}" || true  # Allow failure if namespace doesn't exist yet (Kustomize will create it)
print_success "Namespace context configured"

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
    kustomize edit set image "TODO_APP_BROADCASTER_IMAGE/TAG=${DOCKER_REGISTRY}/todo_app_broadcaster:amd64-v1"
    kustomize edit set image "TODO_APP_BACKUP_JOB_IMAGE/TAG=${DOCKER_REGISTRY}/todo_app_backup_job:amd64-v1"
    popd >/dev/null || exit 1
    print_success "Kustomize images updated"
else
    print_warning "kustomize not installed; using images declared in kustomize.yaml"
fi

# Import images into k3d cluster before applying manifests (only for k3d clusters)
# For GKE, images are pulled from Docker Hub registry automatically
if [ "${IS_K3D}" = "true" ]; then
    print_info "Importing images into k3d cluster (for faster local development)..."
    import_images_to_k3d
else
    print_info "Skipping k3d image import (GKE will pull images from Docker Hub registry)"
fi

# Apply Kustomize manifests
print_info "Applying Kustomize manifests..."
if ! kubectl apply -k "${TODO_APP_ROOT}"; then
    print_error "Failed to apply Kustomize manifests"
    exit 1
fi
print_success "Kustomize apply complete"

# Wait for namespace to be created
print_info "Waiting for namespace to be ready..."
kubectl wait --for=condition=Active namespace/"${NAMESPACE}" --timeout=30s || {
    print_warning "Namespace may not be ready yet"
}
print_success "Namespace is ready"

# ----------------------------------------------------------------------------
# MONITORING SETUP (Hybrid Approach: Helm Charts)
# Run AFTER namespace is created by Kustomize
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
    print_info "MONITORING_SCRIPTS=false → monitoring manifests applied via Kustomize; skipping scripts"
fi

# Force pod restart to use new images
print_info "Restarting pods to use new images..."
kubectl rollout restart deployment/todo-app-frontend-deployment --namespace="${NAMESPACE}" || {
    print_warning "Failed to restart Frontend Deployment (may not exist yet)"
}
kubectl rollout restart deployment/todo-app-backend-deployment --namespace="${NAMESPACE}" || {
    print_warning "Failed to restart Backend Deployment (may not exist yet)"
}
kubectl rollout restart deployment/todo-app-broadcaster-deployment --namespace="${NAMESPACE}" || {
    print_warning "Failed to restart Broadcaster Deployment (may not exist yet)"
}
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

    print_info "Waiting for Frontend Deployment to be available..."
    kubectl rollout status deployment/todo-app-frontend-deployment --namespace="${NAMESPACE}" --timeout=300s || {
        print_warning "Frontend Deployment rollout may not be complete"
    }

    kubectl wait --for=condition=available deployment/todo-app-frontend-deployment --namespace="${NAMESPACE}" --timeout=300s || {
        print_warning "Frontend Deployment may not be available yet"
    }

    print_info "Waiting for Backend Deployment to be available..."
    kubectl rollout status deployment/todo-app-backend-deployment --namespace="${NAMESPACE}" --timeout=300s || {
        print_warning "Backend Deployment rollout may not be complete"
    }

    kubectl wait --for=condition=available deployment/todo-app-backend-deployment --namespace="${NAMESPACE}" --timeout=300s || {
        print_warning "Backend Deployment may not be available yet"
    }

    print_info "Waiting for Broadcaster Deployment to be available..."
    kubectl rollout status deployment/todo-app-broadcaster-deployment --namespace="${NAMESPACE}" --timeout=300s || {
        print_warning "Broadcaster Deployment rollout may not be complete"
    }

    kubectl wait --for=condition=available deployment/todo-app-broadcaster-deployment --namespace="${NAMESPACE}" --timeout=300s || {
        print_warning "Broadcaster Deployment may not be available yet"
    }
# ----------------------------------------------------------------------------
# DEPLOYMENT STATUS
# ----------------------------------------------------------------------------
print_header "📊 DEPLOYMENT STATUS"
print_info "StatefulSets:"
kubectl get statefulsets --namespace="${NAMESPACE}"

print_info "Deployments:"
kubectl get deployments --namespace="${NAMESPACE}"

print_info "Pods:"
kubectl get pods --namespace="${NAMESPACE}"

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
  🌐 Get Ingress IP:
    kubectl get ingress -n ${NAMESPACE} todo-app-ingress
  
  🌐 Frontend & Backend: Use the Ingress IP from above
    Frontend: http://<INGRESS_IP>/
    Backend API: http://<INGRESS_IP>/todos
  
  📝 Note: Frontend uses relative paths, so it works automatically with any Ingress IP

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
