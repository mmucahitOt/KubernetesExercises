#!/bin/bash

# !!! IMPORTANT !!!
# the user should be logged in to Docker Hub before running this script
# docker login

# This script is used to deploy the log_output application to a Kubernetes cluster.
# It is used to test the application in a Kubernetes environment.

# Get the registry name and ports from the command line arguments
_DOCKER_REGISTRY=$1

echo "--------------------------------"
echo "Docker Registry name: $_DOCKER_REGISTRY"
echo "Ports: $_LOG_OUTPUT_PORT $_PING_PONG_PORT"
echo "--------------------------------"

# Resolve directories relative to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
ROOT_DIR="$(cd -- "${LOG_OUTPUT_ROOT}/.." >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_DIR="${LOG_OUTPUT_ROOT}/log_output"
READ_OUTPUT_DIR="${LOG_OUTPUT_ROOT}/read_output"
PING_PONG_DIR="${ROOT_DIR}/ping_pong"
LOG_OUTPUT_ROOT_MANIFESTS_DIR="${LOG_OUTPUT_ROOT}/manifests"
LOG_OUTPUT_MANIFESTS_DIR="${LOG_OUTPUT_DIR}/manifests"
READ_OUTPUT_MANIFESTS_DIR="${READ_OUTPUT_DIR}/manifests"
PING_PONG_MANIFESTS_DIR="${PING_PONG_DIR}/manifests"

# Build the Docker images (use absolute contexts)
docker build -t log_output:latest "${LOG_OUTPUT_DIR}"
docker build -t read_output:latest "${READ_OUTPUT_DIR}"
docker build -t ping_pong:latest "${PING_PONG_DIR}"
echo "Docker image built"

# Tag the images for Docker Hub
docker tag log_output:latest $_DOCKER_REGISTRY/log_output:latest
docker tag read_output:latest $_DOCKER_REGISTRY/read_output:latest
docker tag ping_pong:latest $_DOCKER_REGISTRY/ping_pong:latest
echo "Docker image tagged"

# Push the Docker images to Docker Hub
docker push $_DOCKER_REGISTRY/log_output:latest
docker push $_DOCKER_REGISTRY/read_output:latest
docker push $_DOCKER_REGISTRY/ping_pong:latest
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

# Export variables for substitution in manifest
export DOCKER_REGISTRY=$_DOCKER_REGISTRY
export LOG_OUTPUT_PORT=4000
export PING_PONG_PORT=4001
export READ_OUTPUT_PORT=4002
export LOG_FILE_PATH="/usr/src/app/files/log.txt"
export REQUEST_COUNT_FILE_PATH="/usr/src/app/shared_files/count.txt"
export PING_PONG_URL="http://ping-pong-deployment-svc:2346"

echo "--------------------------------"

echo "Create namespace"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/namespace.yaml" | kubectl create -f -
echo "--------------------------------"

echo "--------------------------------"

echo "Activate namespace"
kubens exercises
echo "--------------------------------"


# Apply the Kubernetes manifest with substituted variables
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/deployment.yaml" | kubectl apply -f -
envsubst < "${PING_PONG_MANIFESTS_DIR}/deployment.yaml" | kubectl apply -f -

echo "--------------------------------"

echo "Persistent Volumes"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/persistent_volume.yaml" | kubectl apply -f -
echo "--------------------------------"

echo "Persistent Volume Claims"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/persistent_volume_claim.yaml" | kubectl apply -f -
echo "--------------------------------"

echo "--------------------------------"
echo "ClusterApi Service"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${LOG_OUTPUT_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
echo "--------------------------------"

# Apply the Kubernetes manifest with substituted variables
envsubst < "${READ_OUTPUT_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
echo "--------------------------------"

# Apply the Kubernetes manifest with substituted variables
envsubst < "${PING_PONG_MANIFESTS_DIR}/service.yaml" | kubectl apply -f -
echo "--------------------------------"


echo "--------------------------------"
echo "Ingress Service"
# Apply the Kubernetes manifest with substituted variables
envsubst < "${LOG_OUTPUT_ROOT_MANIFESTS_DIR}/ingress.yaml" | kubectl apply -f -
echo "--------------------------------"

echo "--------------------------------"
echo "Waiting for deployments to become available..."
kubectl rollout status deployment/log-output-deployment --timeout=300s
kubectl wait --for=condition=available deployment/log-output-deployment --timeout=300s

kubectl rollout status deployment/ping-pong-deployment --timeout=300s
kubectl wait --for=condition=available deployment/ping-pong-deployment --timeout=300s

echo "--------------------------------" 
echo "Deployments"
kubectl get deployments

echo "--------------------------------"

echo "--------------------------------"
echo "Pods"
kubectl get pods

echo "--------------------------------"
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=log-output-deployment --timeout=60s

echo "--------------------------------"
echo "Logs:"
echo "--------------------------------"
kubectl logs deploy/log-output-deployment --all-containers --tail=200

echo "--------------------------------"
echo "Deployment complete"
echo "--------------------------------"

