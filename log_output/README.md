# log_output (upper-level)

This folder contains:

- Common Kubernetes manifests shared across the three apps (`manifests/`)
- Helper scripts to build images and set up monitoring infrastructure (`scripts/`)
- ArgoCD Application manifests for GitOps deployment (`argocd/`)

## GitOps Deployment

This project uses **GitOps** with ArgoCD for automated deployment:

- **Application manifests** are stored in Git (`manifests/`)
- **ArgoCD** watches the Git repository and automatically syncs changes
- **GitHub Actions** builds and pushes Docker images on code changes
- **Kustomize** handles image tag transformations

### Setup

1. **Connect to GKE cluster**:
   ```bash
   gcloud container clusters get-credentials dwk-cluster \
     --zone europe-west1-b \
     --project YOUR_PROJECT_ID
   ```

2. **Install ArgoCD and deploy application** (one-time):
   ```bash
   npm run install-argocd
   ```
   This script will:
   - Install ArgoCD in your GKE cluster
   - Retrieve and display admin credentials
   - Apply the ArgoCD Application manifest
   - Wait for initial sync

3. **Update Git repository URL** (if needed):
   Edit `argocd/applications/log-output-app.yaml` and update the `repoURL` field with your actual Git repository URL.

4. **Deploy monitoring infrastructure** (one-time):
   ```bash
   npm run deploy-monitoring
   ```

## Manifests (`manifests/`)

- `kustomization.yaml`: Kustomize configuration for managing all resources and image transformations
- `deployment.yaml`: Deployments for the applications (images, env vars, volumes, labels)
- `persistent_volume_claim.yaml`: A PVC used by the applications
- `gateway.yaml`: Gateway API configuration for routing
- `config_map.yaml`: Configuration data for applications
- `namespace.yaml`: Namespace definition

## Scripts (`scripts/`)

- `build-images.sh <docker-registry> [tag]`: Builds and pushes Docker images to registry. Used for local development or CI/CD.
- `install_argocd_gke.sh`: Installs ArgoCD in GKE cluster, applies the ArgoCD Application manifest, and sets up GitOps deployment. One-time setup script.
- `kubernetes_deploy_monitoring_stack.sh`: Sets up monitoring infrastructure (Grafana, Prometheus, Loki, Grafana Alloy). One-time setup script.
- `send_request_to_pod.sh <url>`: Creates BusyBox Pod, waits ready, executes request inside cluster, prints result, and deletes the pod.
- `canary_release/canary_deploy.sh <docker-registry> [version]`: Deploys a canary release of the ping_pong application using Argo Rollouts. Builds, tags, and pushes the image, then applies Rollout manifests for gradual traffic shifting. Default version is `amd64-v2`.

## Commands (`package.json`)

From this folder:

```bash
# Install ArgoCD in GKE and deploy application
npm run install-argocd

# Build and push Docker images locally
npm run build-images -- <docker-registry> [tag]

# Deploy monitoring infrastructure (Grafana, Prometheus, Loki)
npm run deploy-monitoring

# Send a request from BusyBox pod (provide URL)
npm run sentRequestToPod -- <url>

# Deploy canary release of ping_pong app (requires stable deployment first)
npm run canary-deploy <docker-registry> [version]
```

### Canary Release

The canary release uses Argo Rollouts to gradually shift traffic from the stable version to the new version:

- **Prerequisites**: Application must be deployed via ArgoCD first
- **Usage**: `npm run canary-deploy <docker-registry> [version]` (default version: `amd64-v2`)
- **Traffic Shifting**: 25% → 50% → 100% (with analysis and pauses)
- **Management Commands**:
  - Check status: `kubectl argo rollouts get rollout ping-pong-rollout -n exercises`
  - Promote to next step: `kubectl argo rollouts promote ping-pong-rollout -n exercises`
  - Abort canary: `kubectl argo rollouts abort ping-pong-rollout -n exercises`

## GitHub Actions

- **`build-and-push-images.yaml`**: Automatically builds and pushes Docker images on code changes, then updates `kustomization.yaml` with new image tags
- **`gitops.yaml`**: Validates Kustomize manifests and ArgoCD Application configurations

## Notes

- **Services** are `ClusterIP`. For external access use `kubectl port-forward`, Gateway API, or Ingress
- **Application deployment** is handled automatically by ArgoCD when changes are pushed to Git
- **Image tags** are updated automatically by GitHub Actions CI/CD pipeline
- **Monitoring** (Grafana, Prometheus, Loki) is set up once using the monitoring script
