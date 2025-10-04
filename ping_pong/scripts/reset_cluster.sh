#!/bin/bash

echo "--------------------------------"
echo "Resetting Kubernetes cluster..."
echo "--------------------------------"

# Stop the cluster if it's running
echo "Stopping cluster..."
k3d cluster stop k3s-default 2>/dev/null || true

# Delete the cluster
echo "Deleting cluster..."
k3d cluster delete k3s-default 2>/dev/null || true

# Wait a moment
sleep 3

# Create a fresh cluster
echo "Creating new cluster..."
k3d cluster create k3s-default --agents 2

# Switch to the new cluster context
kubectl config use-context k3d-k3s-default

echo "--------------------------------"
echo "Cluster reset complete!"
echo "--------------------------------"

# Show cluster info
kubectl cluster-info
