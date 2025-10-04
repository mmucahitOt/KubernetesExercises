# Ping-Pong Application

A stateful web API that tracks ping/pong requests using a PostgreSQL database. The application consists of a Node.js backend API and a PostgreSQL database, deployed as a Kubernetes StatefulSet.

## Application Overview

The ping-pong application provides:

- **Ping endpoint**: `/pingpong` - Returns "pong" with request count
- **Count endpoint**: `/pings` - Returns total ping count
- **Database persistence**: Uses PostgreSQL to store request counts
- **Stateful deployment**: Data persists across Pod restarts

## Architecture

- **Backend**: Node.js Express API server
- **Database**: PostgreSQL with persistent storage
- **Deployment**: Kubernetes StatefulSet with persistent volumes
- **Networking**: Headless service for database, ClusterIP service for API, Ingress for external access

## Scripts

### `scripts/kubernetes_deploy_statefulset.sh`

Deploys the ping-pong application to Kubernetes:

- Builds and pushes Docker images to registry
- Creates k3d cluster with load balancer
- Sets up persistent storage
- Deploys StatefulSet, Services, and Ingress
- Configures environment variables

**Usage**: `./scripts/kubernetes_deploy_statefulset.sh <docker-registry>`

### `scripts/kubernetes_undeploy_statefulset.sh`

Cleans up the deployed application:

- Deletes Kubernetes resources (StatefulSet, Services, Ingress)
- Removes Persistent Volume Claims
- Cleans up Docker images
- Removes all traces of the deployment

**Usage**: `./scripts/kubernetes_undeploy_statefulset.sh <docker-registry>`

## Manifests Directory

### `manifests/deployment/`

Standard Kubernetes Deployment manifests:

- `deployment.yaml` - Deployment for stateless deployment
- `service.yaml` - Service for load balancing
- `persistent_volume_claim.yaml` - PVC for data persistence

### `manifests/statefulset/`

StatefulSet deployment manifests:

- `statefulset.yaml` - StatefulSet with app and database containers
- `headless_service.yaml` - Headless service for database connectivity
- `cluster_ip_service.yaml` - ClusterIP service for API access
- `ingress.yaml` - Ingress for external access

## API Endpoints

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

- `PING_PONG_PORT` - API server port (default: 4001)
- `PING_PONG_DB_URL` - Database connection string
- `DOCKER_REGISTRY` - Docker registry for images

## Access Points

- **API**: `http://localhost/pingpong` (via Ingress)
- **Database**: Internal cluster access via headless service
- **Direct Pod access**: Available via StatefulSet DNS names

## Features

- **Persistent storage**: Database survives Pod restarts
- **Stateful deployment**: Each Pod has unique identity
- **Load balancing**: Multiple replicas supported
- **External access**: Ingress provides external API connectivity
- **Database connectivity**: Headless service enables direct database access
