#!/bin/bash

set -euo pipefail

REQUEST_URL=$1

if [[ -z "${REQUEST_URL}" ]]; then
  echo "Usage: $0 <REQUEST_URL>"
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
LOG_OUTPUT_MANIFESTS_DIR="${LOG_OUTPUT_ROOT}/manifests"

# Always try to clean up the pod on exit
trap 'kubectl delete pod my-busybox --ignore-not-found >/dev/null 2>&1 || true' EXIT

echo "--------------------------------"
kubectl apply -f "${LOG_OUTPUT_MANIFESTS_DIR}/busybox.pod.yaml"

echo "BusyBox Pod created"
echo "--------------------------------"

# Wait for pod to be Ready
kubectl wait --for=condition=Ready pod/my-busybox --timeout=60s

# Retry request until it succeeds or timeout
MAX_WAIT_SECONDS=60
SLEEP_SECONDS=2
ELAPSED=0

echo "Waiting for successful response from: ${REQUEST_URL}"
while true; do
  if RESPONSE=$(kubectl exec -it my-busybox -- sh -c "wget -qO - '${REQUEST_URL}'"); then
    # Successful response captured; print in a readable format and break
    ONE_LINE=${RESPONSE//$'\n'/ }
    ONE_LINE_ESC=${ONE_LINE//\"/\\\"}
    echo "------"
    echo "result : \"${ONE_LINE_ESC}\""
    echo
    echo "${RESPONSE}"
    break
  fi
  if (( ELAPSED >= MAX_WAIT_SECONDS )); then
    echo "Timed out after ${MAX_WAIT_SECONDS}s waiting for successful response from ${REQUEST_URL}" >&2
    exit 1
  fi
  sleep "${SLEEP_SECONDS}"
  ELAPSED=$((ELAPSED + SLEEP_SECONDS))
  echo "Retrying... (${ELAPSED}s)"
done


echo "--------------------------------"
kubectl delete pod my-busybox || true

echo "BusyBox Pod deleted"
echo "--------------------------------"