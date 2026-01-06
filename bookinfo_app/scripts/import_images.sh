#!/bin/bash

CLUSTER_NAME="k3d-cluster"

IMAGES=(
  "istio/examples-bookinfo-details-v1:1.18.0"
  "istio/examples-bookinfo-ratings-v1:1.18.0"
  "istio/examples-bookinfo-reviews-v1:1.18.0"
  "istio/examples-bookinfo-reviews-v2:1.18.0"
  "istio/examples-bookinfo-reviews-v3:1.18.0"
  "istio/examples-bookinfo-productpage-v1:1.18.0"
)

for image in "${IMAGES[@]}"; do
  echo "Pulling $image..."
  docker pull "$image"
  
  echo "Importing $image into k3d cluster..."
  k3d image import "$image" -c "$CLUSTER_NAME"
done

echo "All images imported successfully!"