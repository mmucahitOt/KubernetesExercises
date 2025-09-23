# log_output (upper-level)

This folder contains:
- Common Kubernetes manifests shared across the three apps (`manifests/`)
- Helper scripts to build, deploy, and undeploy the apps (`scripts/`)

## Manifests (`manifests/`)
- `deployment.yaml`: Deployments for the applications (images, env vars, volumes, labels).
- `persistent_volume.yaml`: A PersistentVolume (backed by k3d node path).
- `persistent_volume_claim.yaml`: A PVC used by the applications.
- `ingress.yaml`: Ingress to expose the services via the k3d load balancer.
- `busybox.pod.yaml`: Utility Pod (BusyBox) to run test commands inside the cluster.

## Scripts (`scripts/`)
- `kubernetes_deploy.sh <docker-registry>`: Builds, tags, pushes images; creates/starts k3d if needed; applies PV, PVC, Deployments, Services, and Ingress; waits for rollouts.
- `kubernetes_undeploy.sh <docker-registry>`: Deletes Services, PVC/PV, Deployments, and removes Docker images.
- `reset_cluster.sh`: Recreates a fresh k3d cluster (use with caution).
- `send_request_to_pod.sh <url>`: Creates BusyBox Pod, waits ready, executes request inside cluster, prints result, and deletes the pod.

## Commands (`package.json`)
From this folder:

```bash
# Send a request from BusyBox pod (provide URL)
npm run sentRequestToPod -- <url>

# Deploy all apps to k3d cluster
npm run deploy <docker-registry>

# Undeploy and cleanup
npm run undeploy <docker-registry>
```

Notes:
- Services under each project are `ClusterIP`. For external access use `kubectl port-forward`, Ingress, or publish NodePorts via k3d.
- Ensure environment variables referenced in manifests (e.g., `LOG_OUTPUT_PORT`, `READ_OUTPUT_PORT`, `PING_PONG_URL`) are provided by the deploy script.
