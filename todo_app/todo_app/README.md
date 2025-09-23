# todo_app (server)

## Brief

- Node.js server that serves the built React frontend and an image endpoint
- Static site under `public/` served at `/`
- Uses `RANDOM_IMAGE_PATH` for the `/randomimage` response

## Endpoints

- `GET /` → serves `public/index.html`
- `GET /randomimage` → returns a JPEG from `RANDOM_IMAGE_PATH` with no-cache headers

## Scripts (from this folder)

```bash
# Start locally
npm run start
```

## Manifests (manifests/)

- `service.yaml`
  - kind: Service (`ClusterIP`)
  - name: `todo-app-deployment-svc`
  - selector: `app: todo-app-deployment`
  - ports: `port 2345` → `targetPort ${TODO_APP_PORT}` (TCP)

Notes:

- Service is cluster-internal; reach via Ingress or `kubectl port-forward` in k3d.
- Ensure Deployment exposes the container port matching `TODO_APP_PORT`.
