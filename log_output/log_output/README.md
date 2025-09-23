# Log Output app

## Brief

- HTTP service that logs a fresh UUID to stdout every 5 seconds.
- Exposes an endpoint that returns a timestamp, a process-scoped random UUID, and the ping/pong count fetched from another service.

## Endpoints

- `GET /logoutput`
  - Response contains:
    - ISO timestamp
    - Static UUID (per-process)
    - `Ping / Pong: <count>` from `${PING_PONG_URL}/pingpong-count`

## Scripts (from this folder)

```bash
# Start locally
npm run start
```

## Manifests (manifests/)

- `service.yaml`
  - kind: Service (`ClusterIP`)
  - name: `log-output-deployment-svc`
  - selector: `app: log-output-deployment`
  - ports:
    - port: `2345` (cluster-internal)
    - targetPort: `${LOG_OUTPUT_PORT}` (container port)
  - protocol: `TCP`

Notes:

- Service is cluster-internal; use `kubectl port-forward`, Ingress, or k3d port mapping to reach from host.
- Ensure the Deployment/Pod template uses label `app: log-output-deployment` and exposes the container port matching `LOG_OUTPUT_PORT`.
