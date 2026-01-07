# Log Output Exercise

A Kubernetes service mesh exercise demonstrating traffic splitting, service communication, and observability using Istio, Kiali, Prometheus, and Grafana.

## Overview

This exercise implements a microservices application with:

- **log-output**: Main application that logs UUIDs and integrates with other services
- **greeter**: Greeting service with two versions (v1 and v2) for traffic splitting demonstration
- **ping-pong**: Service for health checks and request counting
- **Traffic splitting**: HTTPRoute configured to split traffic 75% to greeter v1, 25% to greeter v2

## Architecture

```
┌─────────────────┐
│   Gateway       │
│  (Istio)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────┐
│  log-output     │─────▶│  greeter-svc │
│  (main app)     │      │  (75% v1)    │
└────────┬────────┘      │  (25% v2)    │
         │                └──────────────┘
         │
         ▼
┌─────────────────┐
│  ping-pong      │
│  (health check) │
└─────────────────┘
```

## Prerequisites

### 1. k3d Cluster Setup

Create a k3d cluster with sufficient resources for Istio:

```bash
# Create k3d cluster with 3 agent nodes
k3d cluster create k3d-cluster \
  --agents 3 \
  --k3s-arg '--disable=traefik@server:*' \
  --k3s-arg '--disable=servicelb@server:*' \
  --port "8080:80@loadbalancer" \
  --wait

# Install Gateway API CRDs
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/experimental-install.yaml

# Install Istio (sidecar mode recommended for Kiali)
istioctl install \
  --set profile=default \
  --set values.global.platform=k3d \
  --set components.cni.enabled=false \
  -y

# Create namespace and enable sidecar injection
kubectl create namespace exercises
kubectl label namespace exercises istio-injection=enabled --overwrite
```

### 2. Docker Images

Images are configured to pull from `docker.io/mmucahit0/*`.

**For Apple Silicon (arm64) Macs:**

```bash
cd log_output
bash scripts/build-images-k3d.sh docker.io/mmucahit0 arm64-v1 linux/arm64
```

**For Intel (amd64) Macs:**

```bash
cd log_output
bash scripts/build-images.sh docker.io/mmucahit0 amd64-v1
```

## Scripts

### Build Scripts

#### `scripts/build-images-k3d.sh`

Builds and pushes Docker images for k3d (arm64) and automatically imports them into the cluster.

**Usage:**

```bash
bash scripts/build-images-k3d.sh <docker-registry> <image-tag> <platform>
# Example:
bash scripts/build-images-k3d.sh docker.io/mmucahit0 arm64-v1 linux/arm64
```

**What it does:**

- Builds images for: `log_output`, `read_output`, `ping_pong`, `ping_pong_db`, `greeter`
- Tags images with registry prefix
- Pushes to Docker Hub
- Imports images into k3d cluster nodes

#### `scripts/build-images.sh`

Standard build script for amd64 images (for GKE or other cloud platforms).

**Usage:**

```bash
bash scripts/build-images.sh <docker-registry> <image-tag>
```

### Monitoring Scripts

Located in `scripts/monitoring/`:

#### `step1_grafana_prometheus.sh`

Installs Prometheus and Grafana using kube-prometheus-stack Helm chart.

**What it does:**

- Adds Prometheus Community Helm repository
- Installs Prometheus Operator, Prometheus, Grafana, and AlertManager
- Configures ServiceMonitor/PodMonitor discovery
- Sets up persistence (or disables for k3d if no storage class)

**Access:**

```bash
# Grafana
kubectl -n exercises port-forward svc/prometheus-stack-grafana 3000:80
# Visit: http://localhost:3000 (admin/admin123)

# Prometheus
kubectl -n exercises port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090
# Visit: http://localhost:9090
```

#### `step2_grafana_alloy_loki.sh`

Installs Loki (log storage) and Grafana Alloy (log collection agent).

**What it does:**

- Deploys Loki using manifests from `manifests/monitoring/`
- Installs Grafana Alloy via Helm
- Configures automatic log collection from all pods in `exercises` namespace
- Sets up Kubernetes discovery for log collection

**Access:**

```bash
# Loki
kubectl -n exercises port-forward svc/loki 3100:3100
# Visit: http://localhost:3100
```

#### `step3_install_kiali.sh`

Installs Kiali for service mesh observability.

**What it does:**

- Adds Kiali Helm repository
- Installs Kiali in `istio-system` namespace
- Configures Prometheus and Grafana integration
- Creates ServiceMonitor/PodMonitor for Istio metrics
- Sets anonymous authentication (no login required)

**Access:**

```bash
kubectl -n istio-system port-forward svc/kiali 20001:20001
# Visit: http://localhost:20001/kiali
```

#### `configure_grafana_datasources.sh`

Configures Grafana to use Loki and Prometheus as data sources.

**What it does:**

- Adds Loki data source to Grafana
- Verifies Prometheus data source (auto-configured by Helm chart)

**Run after:** `step1_grafana_prometheus.sh` and `step2_grafana_alloy_loki.sh`

### Deployment Scripts

#### `scripts/canary_release/canary_deploy.sh`

Script for canary deployment strategy (if using Argo Rollouts).

#### `scripts/install_argocd_gke.sh`

Installs ArgoCD on GKE (for GitOps deployments).

## Deployment

### Quick Start

```bash
# 1. Build and import images (for k3d/arm64)
cd log_output
bash scripts/build-images-k3d.sh docker.io/mmucahit0 arm64-v1 linux/arm64

# 2. Deploy application
kubectl apply -k manifests/

# 3. Wait for pods to be ready
kubectl get pods -n exercises -w
```

### Manual Deployment Steps

1. **Build images** (if not using script):

   ```bash
   docker build -t docker.io/mmucahit0/log_output:arm64-v1 log_output/log_output
   docker build -t docker.io/mmucahit0/greeter:arm64-v1 greeter
   docker build -t docker.io/mmucahit0/greeter:arm64-v2 greeter
   # ... build other images
   ```

2. **Push and import to k3d**:

   ```bash
   docker push docker.io/mmucahit0/log_output:arm64-v1
   k3d image import docker.io/mmucahit0/log_output:arm64-v1 -c k3d-cluster
   # ... repeat for other images
   ```

3. **Deploy manifests**:

   ```bash
   kubectl apply -k manifests/
   ```

## Application Components

### log-output Service

Main application providing endpoints:

- **`/`**: Health check endpoint
- **`/healthz`**: Health check with ping-pong service validation
- **`/logoutput`**: Returns log information including:
  - File content
  - Environment variables
  - Timestamp and random UUID
  - Ping/Pong count
  - Greeting from greeter service
- **`/status`**: Returns detailed status including greeting

### greeter Service

Simple greeting service with two versions:

- **v1**: Returns "Hello from version 1"
- **v2**: Returns "Hello from version 2"

Traffic is split 75% to v1, 25% to v2 via HTTPRoute.

### ping-pong Service

Service for health checks and request counting, integrated with PostgreSQL database.

## Traffic Splitting Configuration

Traffic splitting is configured via `HTTPRoute` with Service parentRef:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: greeter-route
  namespace: exercises
spec:
  parentRefs:
    - group: ""
      kind: Service
      name: greeter-svc
      port: 3000
  rules:
    - backendRefs:
        - name: greeter-svc-1
          port: 3000
          weight: 75
        - name: greeter-svc-2
          port: 3000
          weight: 25
```

**Note**: This configuration requires Istio's Gateway API implementation.

## Accessing the Application

### For k3d (Local Development)

```bash
# Port-forward the Istio gateway service
kubectl port-forward -n exercises svc/log-output-gateway-istio 8080:80
```

Then access:

- **Status**: `http://localhost:8080/status`
- **Log output**: `http://localhost:8080/logoutput`
- **Health check**: `http://localhost:8080/healthz`

### For GKE (Cloud)

```bash
# Get external IP
kubectl get gateway -n exercises log-output-gateway -o jsonpath='{.status.addresses[0].value}'
```

Access via the external IP on port 80.

## Monitoring Setup

### Install Monitoring Stack

Run scripts in order:

```bash
cd scripts/monitoring

# Step 1: Prometheus + Grafana
bash step1_grafana_prometheus.sh

# Step 2: Loki + Grafana Alloy
bash step2_grafana_alloy_loki.sh

# Step 3: Configure Grafana data sources
bash configure_grafana_datasources.sh

# Step 4: Install Kiali
bash step3_install_kiali.sh
```

### Access Monitoring Tools

```bash
# Grafana
kubectl -n exercises port-forward svc/prometheus-stack-grafana 3000:80
# http://localhost:3000 (admin/admin123)

# Prometheus
kubectl -n exercises port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090
# http://localhost:9090

# Kiali
kubectl -n istio-system port-forward svc/kiali 20001:20001
# http://localhost:20001/kiali

# Loki
kubectl -n exercises port-forward svc/loki 3100:3100
# http://localhost:3100
```

### Monitoring Manifests

Located in `manifests/monitoring/`:

- **`istio-servicemonitor.yaml`**: ServiceMonitor for Istio control plane (istiod)
- **`istio-sidecar-podmonitor.yaml`**: PodMonitor for Istio sidecar proxies (required for Kiali)
- **`loki-*.yaml`**: Loki deployment, service, and ConfigMap
- **`grafana-alloy-values.yaml`**: Helm values for Grafana Alloy log collector

## Verifying Traffic Splitting

### Using Kiali

1. Access Kiali: `kubectl -n istio-system port-forward svc/kiali 20001:20001`
2. Open `http://localhost:20001/kiali`
3. Select namespace: `exercises`
4. Go to **Graph** view
5. Select `greeter-svc` to see traffic distribution between v1 and v2

### Manual Verification

```bash
# Generate traffic and count responses
for i in {1..100}; do
  curl -s http://localhost:8080/status | grep -o "Hello from version [12]"
done | sort | uniq -c

# Expected output (approximately):
#   75 Hello from version 1
#   25 Hello from version 2
```

### Using Prometheus

```bash
# Port-forward Prometheus
kubectl -n exercises port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090

# Query in Prometheus UI (http://localhost:9090):
istio_requests_total{destination_service_name="greeter-svc-1"}
istio_requests_total{destination_service_name="greeter-svc-2"}
```

## Troubleshooting

### Kiali Not Showing Traffic

1. **Verify sidecar injection**:

   ```bash
   kubectl get pod -n exercises -l app=log-output-deployment -o jsonpath='{.items[0].spec.containers[*].name}'
   # Should include: istio-proxy
   ```

2. **Check Prometheus metrics**:

   ```bash
   # Query: istio_requests_total
   # Should return non-empty results
   ```

3. **Verify PodMonitor**:

   ```bash
   kubectl get podmonitor istio-sidecars -n exercises
   ```

4. **Generate traffic**:

   ```bash
   for i in {1..100}; do curl -s http://localhost:8080/logoutput > /dev/null; done
   ```

### Pods Not Starting

1. **Check image availability**:

   ```bash
   kubectl describe pod <pod-name> -n exercises
   # Look for ImagePullBackOff errors
   ```

2. **Import images to k3d**:

   ```bash
   k3d image import docker.io/mmucahit0/<image-name>:<tag> -c k3d-cluster
   ```

### Gateway Not Accessible

1. **Check gateway service**:

   ```bash
   kubectl get svc -n exercises | grep gateway
   ```

2. **Verify HTTPRoute**:

   ```bash
   kubectl get httproute -n exercises
   kubectl describe httproute log-output-http-route -n exercises
   ```

## Project Structure

```
log_output/
├── manifests/              # Kubernetes manifests
│   ├── monitoring/         # Monitoring stack manifests
│   ├── canary_release/     # Canary deployment configs
│   └── ...
├── scripts/                # Automation scripts
│   ├── monitoring/         # Monitoring installation scripts
│   ├── build-images.sh     # Image build script
│   └── build-images-k3d.sh # k3d-specific build script
├── log_output/             # Main application code
├── greeter/                # Greeter service code
└── README.md              # This file
```

## Notes

- **Sidecar Mode**: This exercise uses Istio sidecar mode (not ambient) for full Kiali compatibility
  - **Ambient Mode Limitation**: Ambient mode was tested but could not be made to work with Kiali traffic graphs. The waypoint proxies in ambient mode do not expose metrics in a format that Prometheus/kube-prometheus-stack can easily scrape, and Kiali requires `istio_requests_total` metrics that are only reliably available in sidecar mode. Therefore, sidecar mode is required for this exercise.
- **k3d**: Optimized for k3d local development clusters
- **arm64**: Build scripts support Apple Silicon Macs
- **Monitoring**: Full observability stack included (Prometheus, Grafana, Loki, Kiali)
