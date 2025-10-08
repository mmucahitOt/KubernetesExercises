# todo_app (upper-level)

This folder contains:

- Common Kubernetes manifests shared by the todo app stack (`manifests/`)
- Helper scripts to build, deploy, and undeploy (`scripts/`)
- Subprojects: `todo_app` (server), `todo_app_backend` (API), `todo_app_frontend` (React)
- **NEW**: `todo_app_add_job` (CronJob that automatically adds Wikipedia articles as todos)

## 🎨 Enhanced Scripts with Beautiful Logging

All deployment and undeployment scripts now feature:

- **Color-coded output** with emojis for better readability
- **Step-by-step progress** indicators
- **Success/failure status** for each operation
- **Clear section headers** with visual separators
- **Real-time feedback** during long-running operations

## Manifests (`manifests/`)

- `statefulset.yaml`: StatefulSet spec for the todo app (stable identity + persistent storage)
- `headless_service.yaml`: Headless Service for stable DNS to stateful Pods
- `ingress.yaml`: Ingress to expose services via the k3d load balancer
- `config_map.yaml`: Configuration data for the application

## 🕐 Automated Todo Generation (`todo_app_add_job/`)

**NEW FEATURE**: Automatic Wikipedia article todos via CronJob!

- **CronJob**: Runs every hour to add random Wikipedia articles as todos
- **HTML Links**: Frontend renders Wikipedia links as clickable links with "Read this article. Link:" prefix
- **Database Integration**: Direct PostgreSQL connection to insert todos
- **Docker Image**: Lightweight Alpine-based image with psql and curl
- **Manifest**: `todo_app_add_job/manifests/todo_app_add_job.yaml` (CronJob spec)

## Scripts (`scripts/`)

### 🚀 `kubernetes_deploy.sh <docker-registry>`

**Enhanced deployment script with beautiful logging:**

- 🎨 **Frontend build** with Vite integration and progress tracking
- 🐳 **Docker image building** with step-by-step feedback (includes new CronJob image)
- 📤 **Image pushing** to Docker Hub with status updates
- ☸️ **Kubernetes cluster** setup and management
- 📋 **Manifest application** (applies StatefulSet + Services/Ingress + CronJob) with clear progress indicators
- ⏳ **Deployment waiting** with real-time status updates
- 🎉 **Completion confirmation** with final status

### 🧹 `kubernetes_undeploy.sh <docker-registry>`

**Enhanced cleanup script with beautiful logging:**

- ☸️ **Cluster check** with appropriate messaging
- 🗑️ **Resource deletion** with step-by-step progress
- 🐳 **Docker cleanup** with image removal status
- 🎉 **Cleanup completion** with environment reset confirmation

### 📡 `send_request_to_pod.sh <url>`

Creates BusyBox Pod, waits ready, executes request inside cluster, prints result, and deletes the pod.

## Commands (`package.json`)

From this folder:

```bash
# Send a request from BusyBox pod (provide URL)
npm run sentRequestToPod -- <url>

# Deploy the todo app stack to k3d (with beautiful logging)
npm run deploy <docker-registry>

# Undeploy and cleanup (with beautiful logging)
npm run undeploy <docker-registry>
```

## 🎯 Example Deployment Output

```
================================
🚀 TODO APP DEPLOYMENT STARTING
================================

ℹ️  Docker Registry: mmucahit0
ℹ️  Ports: TODO_APP=4000, TODO_APP_BACKEND=4001

================================
🎨 BUILDING FRONTEND
================================

ℹ️  Building frontend with Vite...
ℹ️  Installing dependencies...
✅ Dependencies installed
ℹ️  Building frontend...
✅ Frontend built successfully

================================
🐳 BUILDING DOCKER IMAGES
================================

ℹ️  Building todo_app image...
✅ todo_app image built
ℹ️  Building todo_app_backend image...
✅ todo_app_backend image built
```

## 🎯 Features

### Frontend Enhancements

- **HTML Link Rendering**: Wikipedia links from CronJob are rendered as clickable links
- **Smart Content Detection**: Automatically detects HTML vs plain text todos
- **User-Friendly Prefix**: HTML todos get "Read this article. Link:" prefix

### Automated Content

- **Hourly Wikipedia Articles**: CronJob adds random Wikipedia articles every hour
- **Direct Database Integration**: CronJob connects directly to PostgreSQL
- **HTML Link Generation**: Articles are stored as clickable HTML links

## 📝 Notes

- Services are `ClusterIP` (in-cluster). Use `kubectl port-forward`/Ingress/k3d `--port` for host access.
- The deploy script sets env needed by manifests (e.g., `TODO_APP_PORT`, `TODO_APP_BACKEND_PORT`, `VITE_TODO_*`).
- The application is deployed as a **StatefulSet** to persist data and provide stable Pod identity.
- **CronJob** runs every hour (`0 * * * *`) to add Wikipedia articles as todos.
- All scripts now provide **real-time feedback** with **color-coded status** and **progress indicators**.
- **Frontend build process** is fully integrated with Vite and includes dependency management.
- **Error handling** is improved with clear error messages and troubleshooting guidance.
