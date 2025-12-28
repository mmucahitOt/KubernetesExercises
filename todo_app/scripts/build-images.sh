#!/bin/bash

# ============================================================================
# DESCRIPTION
# ============================================================================
# This script builds the frontend and all Docker images for the todo_app
# application. It is designed to be used by CI/CD pipelines (GitHub Actions)
# or run manually for local development.
#
# Usage: ./build-images.sh <docker-registry> [image-tag]
#
# Arguments:
#   1. docker-registry (REQUIRED)
#      - Docker registry username or registry URL
#      - Example: "mmucahit0" or "gcr.io/my-project"
#
#   2. image-tag (OPTIONAL, default: amd64-v1)
#      - Tag to use for Docker images
#      - Example: "amd64-v1", "latest", or commit SHA
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
DOCKER_REGISTRY="${1:-}"
if [ -z "${DOCKER_REGISTRY}" ]; then
    print_error "Usage: $0 <docker-registry> [image-tag]"
    print_info "Example: $0 mmucahit0 amd64-v1"
    exit 1
fi

IMAGE_TAG="${2:-amd64-v1}"

# Directory resolution
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
TODO_APP_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
TODO_APP_DIR="${TODO_APP_ROOT}/todo_app"
TODO_APP_BACKEND_DIR="${TODO_APP_ROOT}/todo_app_backend"
TODO_APP_BACKEND_DB_DIR="${TODO_APP_ROOT}/todo_app_backend_db"
TODO_APP_ADD_JOB_DIR="${TODO_APP_ROOT}/todo_app_add_job"
TODO_APP_BACKUP_JOB_DIR="${TODO_APP_ROOT}/todo_app_db_backup_cronjob"
TODO_APP_BROADCASTER_DIR="${TODO_APP_ROOT}/todo_app_broadcaster"
FRONTEND_DIR="${TODO_APP_ROOT}/todo_app_frontend"
FRONTEND_DIST_DIR="${FRONTEND_DIR}/dist"
TODO_PUBLIC_DIR="${TODO_APP_DIR}/public"

# Docker images configuration
IMAGE_TODO_APP="todo_app:${IMAGE_TAG}"
IMAGE_TODO_BACKEND="todo_app_backend:${IMAGE_TAG}"
IMAGE_TODO_BACKEND_DB="todo_app_backend_db:${IMAGE_TAG}"
IMAGE_TODO_ADD_JOB="todo_app_add_job:${IMAGE_TAG}"
IMAGE_TODO_BACKUP_JOB="todo_app_backup_job:${IMAGE_TAG}"
IMAGE_TODO_BROADCASTER="todo_app_broadcaster:${IMAGE_TAG}"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
build_and_push_image() {
    local image_name=$1
    local dockerfile_dir=$2
    local registry_tag="${DOCKER_REGISTRY}/${image_name}"
    
    print_info "Building ${image_name} for linux/amd64 (Buildx, no cache)..."
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

# ============================================================================
# MAIN EXECUTION
# ============================================================================
print_header "🚀 TODO APP - BUILD IMAGES"
print_info "Docker Registry: ${DOCKER_REGISTRY}"
print_info "Image Tag: ${IMAGE_TAG}"

# ----------------------------------------------------------------------------
# FRONTEND BUILD
# ----------------------------------------------------------------------------
print_header "🎨 BUILDING FRONTEND"
if [ -d "${FRONTEND_DIR}" ]; then
    pushd "${FRONTEND_DIR}" >/dev/null || exit 1
    
    print_info "Building frontend with relative paths..."
    print_success "Frontend will use relative paths for API calls"
    
    if command -v npm >/dev/null 2>&1; then
        print_info "Installing dependencies..."
        npm ci || npm install
        print_success "Dependencies installed"
        
        print_info "Building frontend..."
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
build_and_push_image "${IMAGE_TODO_APP}" "${TODO_APP_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_BACKEND}" "${TODO_APP_BACKEND_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_BACKEND_DB}" "${TODO_APP_BACKEND_DB_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_ADD_JOB}" "${TODO_APP_ADD_JOB_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_BACKUP_JOB}" "${TODO_APP_BACKUP_JOB_DIR}" || exit 1
build_and_push_image "${IMAGE_TODO_BROADCASTER}" "${TODO_APP_BROADCASTER_DIR}" || exit 1

print_header "🎉 BUILD COMPLETE"
print_success "All images built and pushed successfully!"
print_info "Registry: ${DOCKER_REGISTRY}"
print_info "Tag: ${IMAGE_TAG}"

