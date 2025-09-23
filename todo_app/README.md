# todo_app (upper-level)

This folder contains:

- Common Kubernetes manifests shared by the todo app stack (`manifests/`)
- Helper scripts to build, deploy, and undeploy (`scripts/`)
- Subprojects: `todo_app` (server), `todo_app_backend` (API), `todo_app_frontend` (React)

## Manifests (`manifests/`)

- `deployment.yaml`: Deployments, env vars, volumes, labels for the stack
- `persistent_volume.yaml`: PersistentVolume backing storage
- `persistent_volume_claim.yaml`: PVC used by the stack
- `ingress.yaml`: Ingress to expose services via the k3d load balancer

## Scripts (`scripts/`)

- `kubernetes_deploy.sh <docker-registry>`: Builds images, pushes to registry, ensures k3d, applies PV/PVC/Deployments/Services/Ingress, waits for rollouts
- `kubernetes_undeploy.sh <docker-registry>`: Deletes Services, PVC/PV, Deployments, and removes Docker images
- `send_request_to_pod.sh <url>`: Creates BusyBox Pod, waits ready, executes request inside cluster, prints result, and deletes the pod.

## Commands (`package.json`)

From this folder:

```bash
# Send a request from BusyBox pod (provide URL)
npm run sentRequestToPod -- <url>

# Deploy the todo app stack to k3d
npm run deploy <docker-registry>

# Undeploy and cleanup
npm run undeploy <docker-registry>
```

Notes:

- Services are `ClusterIP` (in-cluster). Use `kubectl port-forward`/Ingress/k3d `--port` for host access.
- The deploy script sets env needed by manifests (e.g., `TODO_APP_PORT`, `TODO_APP_BACKEND_PORT`, `VITE_TODO_*`).
