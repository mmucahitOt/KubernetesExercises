# Log Output Application

A Node.js application that generates and logs random UUID strings every 5 seconds. This project demonstrates containerization with Docker and deployment to Kubernetes clusters.

**Features:**

- Generates random UUID v4 strings using the `uuid` package
- Logs output to console every 5 seconds
- Containerized with Docker for easy deployment
- Includes Kubernetes deployment and undeployment scripts
- Automated cluster management with k3d for local development

**Technologies Used:**

- Node.js with Express
- Docker for containerization
- Kubernetes for orchestration
- k3d for local Kubernetes cluster management

**Usage:**

```bash
# Deploy to Kubernetes
npm run deploy <docker-registry>

# Undeploy from Kubernetes
npm run undeploy <docker-registry>
```

**Project Structure:**

- `app.js` - Main application logic
- `Dockerfile` - Container configuration
- `scripts/kubernetes_deploy.sh` - Deployment automation
- `scripts/kubernetes_undeploy.sh` - Cleanup automation
