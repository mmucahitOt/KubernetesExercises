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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

if [ -z "$1" ]; then
    print_error "Usage: $0 <docker-registry> [image-tag] [platform]"
    print_info "Example: $0 mmucahit0 amd64-v1 linux/arm64"
    print_info "Platform: linux/amd64 (default, for GKE) or linux/arm64 (for local k3d on Apple Silicon)"
    exit 1
fi

_DOCKER_REGISTRY=$1
_IMAGE_TAG=${2:-amd64-v1}
_PLATFORM=${3:-linux/amd64}

print_header "🐳 BUILDING AND PUSHING DOCKER IMAGES FOR K3D"
print_info "Docker Registry: $_DOCKER_REGISTRY"
print_info "Image Tag: $_IMAGE_TAG"
print_info "Platform: $_PLATFORM"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
ROOT_DIR="$(cd -- "${LOG_OUTPUT_ROOT}/.." >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_DIR="${LOG_OUTPUT_ROOT}/log_output"
READ_OUTPUT_DIR="${LOG_OUTPUT_ROOT}/read_output"
GREETER_DIR="${LOG_OUTPUT_ROOT}/greeter"
PING_PONG_DIR="${ROOT_DIR}/ping_pong"

print_header "🔨 BUILDING IMAGES"
print_info "Building log_output image..."
docker build --platform $_PLATFORM --no-cache -t log_output:${_IMAGE_TAG} "${LOG_OUTPUT_DIR}"
print_success "log_output image built"

print_info "Building read_output image..."
docker build --platform $_PLATFORM --no-cache -t read_output:${_IMAGE_TAG} "${READ_OUTPUT_DIR}"
print_success "read_output image built"

print_info "Building ping_pong image..."
docker build --platform $_PLATFORM --no-cache -t ping_pong:${_IMAGE_TAG} "${PING_PONG_DIR}"
print_success "ping_pong image built"

print_info "Building ping_pong_db image..."
docker build --platform $_PLATFORM --no-cache -t ping_pong_db:${_IMAGE_TAG} "${PING_PONG_DIR}/database"
print_success "ping_pong_db image built"

print_info "Building greeter image..."
docker build --platform $_PLATFORM --no-cache -t greeter:${_IMAGE_TAG} "${GREETER_DIR}"
print_success "greeter image built"

print_header "🏷️  TAGGING IMAGES"
docker tag log_output:${_IMAGE_TAG} $_DOCKER_REGISTRY/log_output:${_IMAGE_TAG}
docker tag read_output:${_IMAGE_TAG} $_DOCKER_REGISTRY/read_output:${_IMAGE_TAG}
docker tag ping_pong:${_IMAGE_TAG} $_DOCKER_REGISTRY/ping_pong:${_IMAGE_TAG}
docker tag ping_pong_db:${_IMAGE_TAG} $_DOCKER_REGISTRY/ping_pong_db:${_IMAGE_TAG}
docker tag greeter:${_IMAGE_TAG} $_DOCKER_REGISTRY/greeter:${_IMAGE_TAG}
print_success "All images tagged"

print_header "📤 PUSHING IMAGES TO REGISTRY"
print_info "Pushing log_output image..."
docker push $_DOCKER_REGISTRY/log_output:${_IMAGE_TAG}
print_success "log_output pushed"

print_info "Pushing read_output image..."
docker push $_DOCKER_REGISTRY/read_output:${_IMAGE_TAG}
print_success "read_output pushed"

print_info "Pushing ping_pong image..."
docker push $_DOCKER_REGISTRY/ping_pong:${_IMAGE_TAG}
print_success "ping_pong pushed"

print_info "Pushing ping_pong_db image..."
docker push $_DOCKER_REGISTRY/ping_pong_db:${_IMAGE_TAG}
print_success "ping_pong_db pushed"

print_info "Pushing greeter image..."
docker push $_DOCKER_REGISTRY/greeter:${_IMAGE_TAG}
print_success "greeter pushed"

print_header "📥 IMPORTING IMAGES TO K3D"
print_info "Importing images to k3d-cluster..."
k3d image import $_DOCKER_REGISTRY/log_output:${_IMAGE_TAG} -c k3d-cluster
k3d image import $_DOCKER_REGISTRY/read_output:${_IMAGE_TAG} -c k3d-cluster
k3d image import $_DOCKER_REGISTRY/ping_pong:${_IMAGE_TAG} -c k3d-cluster
k3d image import $_DOCKER_REGISTRY/ping_pong_db:${_IMAGE_TAG} -c k3d-cluster
k3d image import $_DOCKER_REGISTRY/greeter:${_IMAGE_TAG} -c k3d-cluster
print_success "All images imported to k3d"
print_info "Note: For greeter v2, build separately with: docker build --platform $_PLATFORM -t greeter:arm64-v2 greeter && docker tag greeter:arm64-v2 $_DOCKER_REGISTRY/greeter:arm64-v2 && docker push $_DOCKER_REGISTRY/greeter:arm64-v2 && k3d image import $_DOCKER_REGISTRY/greeter:arm64-v2 -c k3d-cluster"

print_header "🎉 BUILD AND PUSH COMPLETE"
print_success "All images built, pushed, and imported to k3d successfully!"
print_info "Registry: $_DOCKER_REGISTRY"
print_info "Tag: $_IMAGE_TAG"
print_info "Platform: $_PLATFORM"

