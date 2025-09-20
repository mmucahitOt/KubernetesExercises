#!/bin/bash

# !!! IMPORTANT !!!
# the user should be logged in to Docker Hub before running this script
# docker login

# This script is used to deploy the read_output application to a Kubernetes cluster.
# It is used to test the application in a Kubernetes environment.

# Get the registry name from the command line arguments
DOCKER_REGISTRY=$1

echo "--------------------------------"
echo "Docker Registry name: $DOCKER_REGISTRY"
echo "--------------------------------"

# Build the Docker image
docker build -t read_output:latest .
echo "Docker image built"

# Tag the image for Docker Hub
docker tag read_output:latest $DOCKER_REGISTRY/read_output:latest
echo "Docker image tagged"

# Push the Docker image to Docker Hub
docker push $DOCKER_REGISTRY/read_output:latest
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

kubectl create deployment read-output-deployment --image=$DOCKER_REGISTRY/read_output:latest

echo "--------------------------------"
echo "Deployments"
kubectl get deployments

echo "--------------------------------"
echo "Pods"
kubectl get pods

echo "--------------------------------"
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=read-output-deployment --timeout=60s

POD_NAME=$(kubectl get pods | grep "read-output-deployment" | awk '{print $1}')

echo "--------------------------------"
echo "Pod name: $POD_NAME"
echo "--------------------------------"
echo "Logs"
kubectl logs -f $POD_NAME --all-containers=true

echo "--------------------------------"
echo "Deployment complete"
echo "--------------------------------"

