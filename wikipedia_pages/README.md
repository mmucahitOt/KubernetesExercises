# Wikipedia Pages Application

A Kubernetes application that serves Wikipedia pages using nginx, with an init container for initial setup and a sidecar container for periodic updates.

## Architecture

The application consists of three containers in a single Pod:

1. **Init Container**: Downloads the Kubernetes Wikipedia page before the main container starts
2. **Main Container**: nginx serves the HTML content from a shared volume
3. **Sidecar Container**: Waits 5-15 minutes, then downloads a random Wikipedia page and updates the served content

## Components

### Containers

- **init-download**: Downloads `https://en.wikipedia.org/wiki/Kubernetes` to `/www/index.html`
- **nginx**: Serves content from `/usr/share/nginx/html` (mounted from shared volume)
- **sidecar-updater**: Waits randomly 5-15 minutes, then downloads a random Wikipedia page

### Volumes

- **www-content**: `emptyDir` volume shared by all containers
  - Mounted at `/www` in init and sidecar containers
  - Mounted at `/usr/share/nginx/html` in nginx container

## Deployment

```bash
# Apply ConfigMap with scripts
kubectl apply -f manifests/configmap.yaml

# Apply Deployment
kubectl apply -f manifests/deployment.yaml

# Apply Service
kubectl apply -f manifests/service.yaml
```

## Access

### Port-forward

```bash
kubectl port-forward svc/wikipedia-pages 8080:80
```

Then visit: `http://localhost:8080`

### Expected Behavior

1. **Initial**: nginx serves the Kubernetes Wikipedia page (downloaded by init container)
2. **After 5-15 minutes**: Sidecar downloads a random Wikipedia page, and nginx serves the new content

## Verification

```bash
# Check pod status
kubectl get pods -l app=wikipedia-pages

# Check init container logs
kubectl logs <pod-name> -c init-download

# Check sidecar container logs
kubectl logs <pod-name> -c sidecar-updater

# Check nginx container logs
kubectl logs <pod-name> -c nginx

# Verify content is being served
curl http://localhost:8080 | head -20
```

## Files

- `manifests/deployment.yaml`: Pod definition with all three containers
- `manifests/configmap.yaml`: Scripts for init and sidecar containers
- `manifests/service.yaml`: Service to expose nginx
- `scripts/init-download.sh`: Init container script
- `scripts/sidecar-update.sh`: Sidecar container script

