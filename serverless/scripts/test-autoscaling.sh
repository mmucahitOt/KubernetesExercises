#!/bin/bash

set -e

SERVICE_URL="hello.default.172.18.0.3.sslip.io"
PORT="8081"

echo "Generating traffic to test autoscaling..."
echo "Watch pods in another terminal: kubectl get pods -l serving.knative.dev/service=hello -w"

for i in {1..50}; do
  curl -s -H "Host: ${SERVICE_URL}" http://localhost:${PORT} > /dev/null
  echo -n "."
  sleep 0.1
done

echo ""
echo "Done! Check pod count:"
kubectl get pods -l serving.knative.dev/service=hello

