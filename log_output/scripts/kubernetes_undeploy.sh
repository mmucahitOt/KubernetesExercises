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

  kubectl delete deployment log-output-deployment

  echo "--------------------------------"
  echo "Deployment deleted"
  echo "--------------------------------"

  docker rmi $DOCKER_REGISTRY/log_output:latest

  echo "--------------------------------"
  echo "Docker image removed"
  echo "--------------------------------"
fi
