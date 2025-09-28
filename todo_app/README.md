# todo_app (upper-level)

This folder contains:

- Common Kubernetes manifests shared by the todo app stack (`manifests/`)
- Helper scripts to build, deploy, and undeploy (`scripts/`)
- Subprojects: `todo_app` (server), `todo_app_backend` (API), `todo_app_frontend` (React)

## 🎨 Enhanced Scripts with Beautiful Logging

All deployment and undeployment scripts now feature:

- **Color-coded output** with emojis for better readability
- **Step-by-step progress** indicators
- **Success/failure status** for each operation
- **Clear section headers** with visual separators
- **Real-time feedback** during long-running operations

## Manifests (`manifests/`)

- `deployment.yaml`: Deployments, env vars, volumes, labels for the stack
- `persistent_volume.yaml`: PersistentVolume backing storage
- `persistent_volume_claim.yaml`: PVC used by the stack
- `ingress.yaml`: Ingress to expose services via the k3d load balancer
- `config_map.yaml`: Configuration data for the application

## Scripts (`scripts/`)

### 🚀 `kubernetes_deploy.sh <docker-registry>`

**Enhanced deployment script with beautiful logging:**

- 🎨 **Frontend build** with Vite integration and progress tracking
- 🐳 **Docker image building** with step-by-step feedback
- 📤 **Image pushing** to Docker Hub with status updates
- ☸️ **Kubernetes cluster** setup and management
- 📋 **Manifest application** with clear progress indicators
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

## 📝 Notes

- Services are `ClusterIP` (in-cluster). Use `kubectl port-forward`/Ingress/k3d `--port` for host access.
- The deploy script sets env needed by manifests (e.g., `TODO_APP_PORT`, `TODO_APP_BACKEND_PORT`, `VITE_TODO_*`).
- All scripts now provide **real-time feedback** with **color-coded status** and **progress indicators**.
- **Frontend build process** is fully integrated with Vite and includes dependency management.
- **Error handling** is improved with clear error messages and troubleshooting guidance.
