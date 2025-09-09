#!/bin/bash

# !!! IMPORTANT !!!
# the user should be logged in to Docker Hub before running this script
# docker login

# This script is used to deploy the todo_app application to a Kubernetes cluster.
# It is used to test the application in a Kubernetes environment.

# Get the registry name from the command line arguments
_DOCKER_REGISTRY=$1

_PORT=$2

echo "--------------------------------"
echo "Docker Registry name: $_DOCKER_REGISTRY"
echo "Port: $_PORT"
echo "--------------------------------"

# Build the Docker image
docker build -t todo_app:latest .
echo "Docker image built"

# Tag the image for Docker Hub
docker tag todo_app:latest $_DOCKER_REGISTRY/todo_app:latest
echo "Docker image tagged"

# Push the Docker image to Docker Hub
docker push $_DOCKER_REGISTRY/todo_app:latest
echo "Docker image pushed to Docker Hub"

EXISTING_CONTEXT=$(kubectl config get-contexts | grep "k3d-k3s-default")

if [ -z "$EXISTING_CONTEXT" ]; then
  echo "--------------------------------"
  echo "There is no cluster"
  echo "--------------------------------"
  k3d cluster create k3s-default --agents 2
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

# Export variables for substitution in manifest
export DOCKER_REGISTRY=$_DOCKER_REGISTRY
export PORT=$_PORT

# Apply the Kubernetes manifest with substituted variables
envsubst < manifests/deployment.yaml | kubectl apply -f -

echo "--------------------------------" 
echo "Deployments"
kubectl get deployments

echo "--------------------------------"
echo "Waiting for deployment to become available..."
kubectl rollout status deployment/todo-app-deployment --timeout=90s
kubectl wait --for=condition=available deployment/todo-app-deployment --timeout=90s

echo "--------------------------------"
echo "PORT FORWARD -> 3003:${PORT}"
echo "--------------------------------"
kubectl port-forward deploy/todo-app-deployment 3003:${PORT} >/tmp/pf.log 2>&1 & echo $! >/tmp/pf.pid

echo "--------------------------------"
echo "Pods"
kubectl get pods

echo "--------------------------------"
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=todo-app-deployment --timeout=60s

POD_NAME=$(kubectl get pods | grep "todo-app-deployment" | awk '{print $1}')

echo "--------------------------------"
echo "Pod name: $POD_NAME"
echo "--------------------------------"
echo "Logs"
kubectl logs $POD_NAME

echo "--------------------------------"
echo "Deployment complete"
echo "--------------------------------"

