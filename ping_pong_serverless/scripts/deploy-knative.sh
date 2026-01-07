#!/bin/bash

set -e

DOCKER_REGISTRY=${1:-mmucahit0}
NAMESPACE="exercises"

echo "Deploying ping-pong-serverless as Knative Service..."
echo "Using Docker registry: ${DOCKER_REGISTRY}"

kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying database StatefulSet..."
kubectl apply -f manifests/statefulset/statefulset.yaml
kubectl apply -f manifests/statefulset/headless_service.yaml

echo "Waiting for database to be ready..."
kubectl wait --for=condition=ready pod -l app=ping-pong-serverless-stset -n ${NAMESPACE} --timeout=120s

echo "Deploying Knative Service..."
kubectl apply -f manifests/knative/knative-service.yaml

echo "Waiting for Knative Service to be ready..."
kubectl wait --for=condition=Ready ksvc/ping-pong-serverless -n ${NAMESPACE} --timeout=120s

echo "Getting service URL..."
kubectl get ksvc ping-pong-serverless -n ${NAMESPACE}

echo ""
echo "Service deployed! Get the URL with:"
echo "kubectl get ksvc ping-pong-serverless -n ${NAMESPACE} -o jsonpath='{.status.url}'"

