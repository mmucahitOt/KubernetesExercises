#!/bin/bash

# This script is used to undeploy the log_output application from a Kubernetes cluster.
# It is used to clean up the environment after testing.

# Get the registry name from the command line arguments
DOCKER_REGISTRY=$1

echo "--------------------------------"
echo "Docker Registry name: $DOCKER_REGISTRY"
echo "--------------------------------"


EXISTING_CONTEXT=$(kubectl config get-contexts | grep "k3d-k3s-default")

if [ -z "$EXISTING_CONTEXT" ]; then
  echo "--------------------------------"
  echo "There is no cluster"
  echo "--------------------------------"
else
  echo "--------------------------------"
  echo "There is a cluster"
  echo "--------------------------------"

  kubectl config use-context k3d-k3s-default

  echo "--------------------------------"
  echo "Context switched to cluster"
  echo "--------------------------------"

  kubectl delete service todo-app-deployment-svc
  kubectl delete service todo-app-backend-deployment-svc

  echo "--------------------------------"
  echo "Services deleted"
  echo "--------------------------------"

  kubectl delete pvc todo-app-claim

  echo "--------------------------------"
  echo "PVCs deleted"
  echo "--------------------------------"

  kubectl delete pv todo-app-volume

  echo "--------------------------------"
  echo "PV deleted"
  echo "--------------------------------"

  kubectl delete deployment todo-app-deployment

  echo "--------------------------------"
  echo "Deployments deleted"
  echo "--------------------------------"

  docker rmi $DOCKER_REGISTRY/todo_output:latest

  echo "--------------------------------"
  echo "Docker images removed"
  echo "--------------------------------"
fi
