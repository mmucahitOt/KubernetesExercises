# Read Output app

## Brief

- HTTP service that reads the log file and returns its full contents.
- Intended to demonstrate reading from a shared path or mounted volume.

## Endpoints

- `GET /readoutput`
  - Returns the contents of the file at `LOG_FILE_PATH`.

## Scripts (from this folder)

```bash
# Start locally
npm run start
```

## Manifests (manifests/)

- `service.yaml`
  - kind: Service (`ClusterIP`)
  - name: `read-output-svc`
  - selector: `app: log-output-deployment`
  - ports:
    - port: `2347` (cluster-internal)
    - targetPort: `${READ_OUTPUT_PORT}` (container port)
  - protocol: `TCP`

Notes:

- Service is cluster-internal; use `kubectl port-forward`, Ingress, or k3d port mapping to reach from host.
- Ensure the Deployment/Pod template uses label `app: log-output-deployment` and exposes the container port matching `READ_OUTPUT_PORT`.
