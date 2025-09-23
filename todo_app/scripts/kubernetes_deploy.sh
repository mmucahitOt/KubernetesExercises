#!/bin/bash

# !!! IMPORTANT !!!
# the user should be logged in to Docker Hub before running this script
# docker login

# This script is used to deploy the todo_app application to a Kubernetes cluster.
# It is used to test the application in a Kubernetes environment.

# Get the registry name and ports from the command line arguments
_DOCKER_REGISTRY=$1

# Export variables for substitution in manifest
export DOCKER_REGISTRY=$_DOCKER_REGISTRY
export TODO_APP_PORT=4000
export TODO_APP_BACKEND_PORT=4001
export RANDOM_IMAGE_PATH="/app/files/image.jpeg"
export VITE_TODO_API_URL="http://localhost:8081"
export VITE_TODO_BACKEND_API_URL="http://localhost:8081"

echo "--------------------------------"
echo "Docker Registry name: $_DOCKER_REGISTRY"
echo "Ports: $TODO_APP_PORT, $TODO_APP_BACKEND_PORT"
echo "--------------------------------"

# Resolve directories relative to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
TODO_APP_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
ROOT_DIR="$(cd -- "${TODO_APP_ROOT}/.." >/dev/null 2>&1 && pwd -P)"
TODO_APP_DIR="${TODO_APP_ROOT}/todo_app"
TODO_APP_BACKEND_DIR="${TODO_APP_ROOT}/todo_app_backend"
FRONTEND_DIR="${TODO_APP_ROOT}/todo_app_frontend"
FRONTEND_DIST_DIR="${FRONTEND_DIR}/dist"
TODO_PUBLIC_DIR="${TODO_APP_DIR}/public"
TODO_APP_ROOT_MANIFESTS_DIR="${TODO_APP_ROOT}/manifests"
TODO_APP_MANIFESTS_DIR="${TODO_APP_DIR}/manifests"
TODO_APP_BACKEND_MANIFESTS_DIR="${TODO_APP_BACKEND_DIR}/manifests"

# Build frontend and move output to backend public
echo "--------------------------------"
echo "Building frontend (Vite)"
echo "--------------------------------"
if [ -d "${FRONTEND_DIR}" ]; then
  pushd "${FRONTEND_DIR}" >/dev/null
  if command -v npm >/dev/null 2>&1; then
    npm ci || npm install
    npm run build
  else
    echo "npm is not installed; cannot build frontend" >&2
    exit 1
  fi
  popd >/dev/null

  echo "--------------------------------"
  echo "Copying frontend dist to backend public"
  echo "--------------------------------"
  mkdir -p "${TODO_PUBLIC_DIR}"
  rm -rf "${TODO_PUBLIC_DIR}/"*
  cp -R "${FRONTEND_DIST_DIR}/." "${TODO_PUBLIC_DIR}/"
else
  echo "Frontend directory not found at ${FRONTEND_DIR}; skipping frontend build"
fi

# Build the Docker images (use absolute context)
docker build -t todo_app:latest "${TODO_APP_DIR}"
docker build -t todo_app_backend:latest "${TODO_APP_BACKEND_DIR}"

echo "Docker images built"

# Tag the images for Docker Hub
docker tag todo_app:latest $_DOCKER_REGISTRY/todo_app:latest
docker tag todo_app_backend:latest $_DOCKER_REGISTRY/todo_app_backend:latest
echo "Docker images tagged"

# Push the Docker images to Docker Hub
docker push $_DOCKER_REGISTRY/todo_app:latest
docker push $_DOCKER_REGISTRY/todo_app_backend:latest
echo "Docker images pushed to Docker Hub"

EXISTING_CONTEXT=$(kubectl config get-contexts | grep "k3d-k3s-default")

if [ -z "$EXISTING_CONTEXT" ]; then
  echo "--------------------------------"
  echo "There is no cluster"
  echo "--------------------------------"
  k3d cluster create -p 8081:80@loadbalancer --agents 2
  kubectl config use-context k3d-k3s-default
  echo "--------------------------------"
  echo "Cluster created and context switched to it"
  echo "--------------------------------"
else
  echo "--------------------------------"
  echo "There is a cluster"
  echo "--------------------------------"
  kubectl config use-context k3d-k3s-default
  echo "--------------------------------"
  echo "Context switched to cluster"
  echo "--------------------------------"
fi

kubectl cluster-info

k3d cluster start
echo "--------------------------------"
echo "Cluster started"
echo "--------------------------------"

# Create the directory for persistent storage
echo "--------------------------------"
echo "Creating storage directory on node"
docker exec k3d-k3s-default-agent-0 mkdir -p /tmp/kube
echo "--------------------------------"

# Apply the Kubernetes manifest with substituted variables
envsubst < "${TODO_APP_ROOT_MANIFESTS_DIR}/deployment.yaml" | kubectl apply -f -

echo "--------------------------------"

echo "Persistent Volumes"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${TODO_APP_ROOT_MANIFESTS_DIR}/persistent_volume.yaml" | kubectl apply -f -
echo "--------------------------------"

echo "Persistent Volume Claims"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${TODO_APP_ROOT_MANIFESTS_DIR}/persistent_volume_claim.yaml" | kubectl apply -f -
echo "--------------------------------"

echo "--------------------------------"
echo "ClusterApi Services"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${TODO_APP_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -

# Apply the Kubernetes manifest with substituted variables
envsubst < "${TODO_APP_BACKEND_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
echo "--------------------------------"


echo "--------------------------------"
echo "Ingress Service"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${TODO_APP_ROOT_MANIFESTS_DIR}/ingress.yaml" | kubectl apply -f -
echo "--------------------------------"

echo "--------------------------------"
echo "Waiting for deployments to become available..."
kubectl rollout status deployment/todo-app-deployment --timeout=300s
kubectl wait --for=condition=available deployment/todo-app-deployment --timeout=300s

echo "--------------------------------" 
echo "Deployments"
kubectl get deployments

echo "--------------------------------"

echo "--------------------------------"
echo "Pods"
kubectl get pods

echo "--------------------------------"
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=todo-app-deployment --timeout=60s

echo "--------------------------------"
echo "Logs:"
echo "--------------------------------"
kubectl logs deploy/todo-app-deployment --all-containers --tail=200

echo "--------------------------------"
echo "Deployment complete"
echo "--------------------------------"

