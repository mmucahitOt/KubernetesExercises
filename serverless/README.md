# Knative Serverless Exercise

This exercise demonstrates serverless computing on Kubernetes using Knative Serving.

## Prerequisites

- k3d cluster running (k3s-default)
- Port 8081:80 mapped to loadbalancer
- Traefik disabled (for Kourier)

## Installation

Knative Serving is installed with:

- Knative Serving CRDs and core components
- Kourier networking layer
- Magic DNS (sslip.io) for local development

## Components

- **Knative Serving**: Serverless platform on Kubernetes
- **Kourier**: Lightweight ingress for Knative
- **Activator**: Handles scale-to-zero and cold starts
- **Autoscaler**: Manages automatic scaling based on traffic
- **Controller**: Manages Knative resources

## Exercise 1: Deploy First Service

```bash
kubectl apply -f manifests/hello-service.yaml
kubectl get ksvc hello
```

Access the service:

```bash
curl -H "Host: hello.default.172.18.0.3.sslip.io" http://localhost:8081
```

## Exercise 2: Test Autoscaling

1. Watch pods scale:

```bash
kubectl get pods -l serving.knative.dev/service=hello -w
```

2. Generate traffic:

```bash
bash scripts/test-autoscaling.sh
```

3. Observe scale-to-zero (wait 60-90 seconds after traffic stops):

```bash
kubectl get pods -l serving.knative.dev/service=hello
```

## Exercise 3: Traffic Splitting

1. Deploy v2 with traffic splitting:

```bash
kubectl apply -f manifests/hello-v2-service.yaml
```

2. Check traffic distribution:

```bash
kubectl get ksvc hello -o yaml | grep -A 10 traffic
```

3. Test traffic splitting:

```bash
for i in {1..20}; do
  curl -s -H "Host: hello.default.172.18.0.3.sslip.io" http://localhost:8081
  echo ""
done
```

You should see ~80% "Hello World!" (v1) and ~20% "Hello Knative v2!" (v2) responses.

## Useful Commands

- List services: `kubectl get ksvc`
- List revisions: `kubectl get revisions`
- Service details: `kubectl describe ksvc hello`
- Pod logs: `kubectl logs -l serving.knative.dev/service=hello -c user-container`
