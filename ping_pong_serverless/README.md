# Ping-Pong-Serverless Application

A serverless web API that tracks ping/pong requests using a PostgreSQL database. The application consists of a Node.js backend API deployed as a Knative Service and a PostgreSQL database deployed as a Kubernetes StatefulSet.

## Application Overview

The ping-pong-serverless application provides:

- **Ping endpoint**: `/pingpong` - Returns "pong" with request count
- **Count endpoint**: `/pings` - Returns total ping count
- **Health endpoint**: `/healthz` - Health check endpoint
- **Database persistence**: Uses PostgreSQL to store request counts
- **Serverless deployment**: Auto-scaling and scale-to-zero capabilities

## Architecture

- **Backend**: Node.js Express API server (Knative Service)
- **Database**: PostgreSQL with persistent storage (StatefulSet)
- **Deployment**: Knative Service for API, StatefulSet for database
- **Networking**: Headless service for database, Knative Service for API

## Prerequisites

- Kubernetes cluster with Knative Serving installed
- `kubectl` configured to access the cluster
- Docker installed (for building images)
- For k3d: Images must be built for ARM64 and imported into the cluster

## Deployment

### Build Images

For k3d on ARM64 Macs, build images for the correct platform:

```bash
# Build application image
cd ping_pong_serverless
docker buildx build --platform linux/arm64 -t ping_pong_serverless:arm64-v1 --load .

# Build database image
cd database
docker buildx build --platform linux/arm64 -t ping_pong_serverless_db:arm64-v1 --load .
cd ..
```

### Import Images to k3d

If using k3d, import images into the cluster:

```bash
k3d image import ping_pong_serverless:arm64-v1 ping_pong_serverless_db:arm64-v1 -c <cluster-name>

# Tag with .local suffix for Knative (skips digest resolution)
docker tag ping_pong_serverless:arm64-v1 ping_pong_serverless.local:arm64-v1
k3d image import ping_pong_serverless.local:arm64-v1 -c <cluster-name>
```

### Deploy with Knative

Deploy the ping-pong-serverless application as a Knative Service:

```bash
./scripts/deploy-knative.sh [docker-registry]
```

**Arguments:**

- `docker-registry` (optional): Docker registry prefix (defaults to `mmucahit0`)

**What it does:**

- Creates `exercises` namespace
- Deploys database StatefulSet
- Deploys Knative Service for the API
- Waits for services to be ready
- Displays service URL

**Examples:**

```bash
# Use default registry (mmucahit0)
./scripts/deploy-knative.sh

# Specify custom registry
./scripts/deploy-knative.sh docker.io/myregistry
```

## Manifests

### `manifests/statefulset/`

Database deployment manifests:

- `statefulset.yaml` - PostgreSQL StatefulSet with persistent storage (uses `local-path` storage class for k3d)
- `headless_service.yaml` - Headless service for database connectivity

**Note:** Images are hardcoded in manifests:

- Database: `ping_pong_serverless_db:arm64-v1`
- API: `ping_pong_serverless.local:arm64-v1` (`.local` suffix for Knative to skip digest resolution)

### `manifests/knative/`

Knative Service deployment manifests:

- `knative-service.yaml` - Knative Service for serverless API deployment
  - Uses `imagePullPolicy: Never` for local k3d images
  - Configured for ARM64 architecture

## API Endpoints

- **GET `/`** - Health check (returns "OK")
- **GET `/healthz`** - Health check with database connectivity verification
- **GET `/pingpong`** - Returns "pong" with current request count
- **GET `/pings`** - Returns total ping count as number

## Database Schema

The PostgreSQL database includes:

- `ping_count` table with columns:
  - `id` (SERIAL PRIMARY KEY)
  - `count` (INTEGER) - Current ping count
  - `created_at` (TIMESTAMPTZ)
  - `updated_at` (TIMESTAMPTZ)

## Environment Variables

- `PORT` - API server port (Knative standard, defaults to 8080)
- `PING_PONG_SERVERLESS_PORT` - API server port (fallback, defaults to 3002)
- `PING_PONG_SERVERLESS_DB_URL` - Database connection string

## Accessing the Service

### Get Service URL

```bash
kubectl get ksvc ping-pong-serverless -n exercises -o jsonpath='{.status.url}'
```

### Access via Port-Forward

If using k3d with port mapping (e.g., `8081:80`):

```bash
# Get the service URL
SERVICE_URL=$(kubectl get ksvc ping-pong-serverless -n exercises -o jsonpath='{.status.url}' | sed 's|http://||')

# Access the service
curl -H "Host: ${SERVICE_URL}" http://localhost:8081/pingpong
curl -H "Host: ${SERVICE_URL}" http://localhost:8081/pings
```

### Direct Access (with DNS configured)

If DNS is properly configured for Knative:

```bash
SERVICE_URL=$(kubectl get ksvc ping-pong-serverless -n exercises -o jsonpath='{.status.url}')
curl ${SERVICE_URL}/pingpong
curl ${SERVICE_URL}/pings
```

## Serverless Features

- **Auto-scaling**: Automatically scales based on incoming traffic
- **Scale-to-zero**: Pods terminate when idle (saves resources)
- **Automatic URL**: Each service gets a unique URL
- **Traffic splitting**: Easy canary/blue-green deployments
- **Request-driven**: Scales up instantly when traffic arrives

## Testing Autoscaling

1. Watch pods scale:

```bash
kubectl get pods -l serving.knative.dev/service=ping-pong-serverless -n exercises -w
```

2. Generate traffic:

```bash
SERVICE_URL=$(kubectl get ksvc ping-pong-serverless -n exercises -o jsonpath='{.status.url}' | sed 's|http://||')
for i in {1..50}; do
  curl -s -H "Host: ${SERVICE_URL}" http://localhost:8081/pingpong > /dev/null
done
```

3. Observe scale-to-zero (wait 60-90 seconds after traffic stops):

```bash
kubectl get pods -l serving.knative.dev/service=ping-pong-serverless -n exercises
```

## Useful Commands

- List services: `kubectl get ksvc -n exercises`
- List revisions: `kubectl get revisions -n exercises`
- Service details: `kubectl describe ksvc ping-pong-serverless -n exercises`
- Pod logs: `kubectl logs -l serving.knative.dev/service=ping-pong-serverless -n exercises -c user-container`
- Database pods: `kubectl get pods -l app=ping-pong-serverless-stset -n exercises`

## Troubleshooting

### Image Pull Errors

If you see image pull errors:

- Ensure images are built for the correct platform (ARM64 for Apple Silicon)
- For k3d: Import images using `k3d image import`
- For Knative: Use `.local` suffix or configure `registries-skipping-tag-resolving` in Knative config

### Database Not Ready

If database pod is stuck in `Pending`:

- Check storage class: `kubectl get storageclass`
- For k3d, ensure `local-path` storage class exists
- Check PVC status: `kubectl get pvc -n exercises`

### Knative Service Not Ready

If service shows `RevisionMissing`:

- Check revision status: `kubectl describe revision <revision-name> -n exercises`
- Verify image exists in cluster nodes
- Check Knative controller logs: `kubectl logs -n knative-serving -l app=controller`

## Cleanup

To remove the deployment:

```bash
kubectl delete ksvc ping-pong-serverless -n exercises
kubectl delete statefulset ping-pong-serverless-stset -n exercises
kubectl delete svc ping-pong-serverless-stset-db-svc -n exercises
kubectl delete pvc -l app=ping-pong-serverless-stset -n exercises
```
