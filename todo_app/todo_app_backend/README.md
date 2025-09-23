# todo_app_backend (API)

## Brief

- Express API providing a simple in-memory todo list
- CORS enabled for browser access

## Endpoints

- `GET /todos` → returns all todos
- `POST /todos` with body `{ "text": "..." }` → creates a todo and returns it

## Scripts (from this folder)

```bash
# Start locally
npm run start
```

## Manifests (manifests/)

- `service.yaml`
  - kind: Service (`ClusterIP`)
  - name: `todo-app-backend-deployment-svc`
  - selector: `app: todo-app-deployment`
  - ports: `port 2346` → `targetPort ${TODO_APP_BACKEND_PORT}` (TCP)

Notes:

- Service is cluster-internal; use Ingress or `kubectl port-forward`.
- Ensure Deployment exposes the container port matching `TODO_APP_BACKEND_PORT`.
