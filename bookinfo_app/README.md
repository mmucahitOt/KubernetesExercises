## Bookinfo App with Istio – What I Did and What Happens

This folder contains the Istio **Bookinfo** sample application, deployed following the steps in the Istio docs for the ambient getting started guide ([Deploy a sample application](https://istio.io/latest/docs/ambient/getting-started/deploy-sample-app/)).

Below is a brief description of each step I ran and what happens in the cluster.

---

### 1. Deploy the Bookinfo application

**Commands I ran (conceptually):**

```bash
kubectl apply -f manifests/bookinfo.yaml
kubectl apply -f manifests/bookinfo_versions.yaml
```

**What this does:**

- Creates **Services**, **ServiceAccounts** and **Deployments** for:
  - `productpage`, `details`, `reviews` (v1, v2, v3), `ratings`.
- Kubernetes scheduler places Pods on nodes, and each Service gets:
  - A **ClusterIP**.
  - A **DNS name** (for example `productpage.default.svc.cluster.local`).
- After this step, all Bookinfo microservices can talk to each other **inside** the cluster using Kubernetes DNS (e.g. `http://reviews:9080`), but nothing is exposed outside the cluster yet.

---

### 2. Deploy and configure the ingress gateway

**Commands I ran (conceptually):**

```bash
kubectl apply -f manifests/bookinfo_gateway.yaml

# From the docs:
kubectl annotate gateway bookinfo-gateway \
  networking.istio.io/service-type=ClusterIP \
  --namespace=default
```

**What this does:**

- `bookinfo_gateway.yaml` defines:
  - A `Gateway` named `bookinfo-gateway` with `gatewayClassName: istio`.
  - An `HTTPRoute` that:
    - Matches paths like `/productpage`, `/static`, `/login`, `/logout`, `/api/v1/products`.
    - Routes those requests to the `productpage` Service on port `9080`.
- When I create the `Gateway`:
  - Istio control plane (`istiod`) programs the data plane and creates a **gateway implementation**:
    - A Deployment and Service named `bookinfo-gateway-istio` (in the `default` namespace).
  - The annotation `networking.istio.io/service-type=ClusterIP` changes the generated service type from `LoadBalancer` to **ClusterIP**, which is better for local clusters (like k3d) where there is no cloud load balancer.
- After this step:
  - The gateway service `bookinfo-gateway-istio` listens on port **80** **inside** the cluster.
  - Traffic that reaches this gateway service and matches the `HTTPRoute` will be forwarded to the `productpage` Service.

---

### 3. Access the application via port-forward

**Command I ran:**

```bash
kubectl -n default port-forward svc/bookinfo-gateway-istio 8080:80
```

**What this does:**

- Forwards local `localhost:8080` on my machine to port `80` of the `bookinfo-gateway-istio` service in the cluster.
- When I open:

```text
http://localhost:8080/productpage
```

the request flow is:

1. **Browser → Localhost:8080**

   - HTTP request to `localhost:8080/productpage`.

2. **Port-forward → Gateway service**

   - `kubectl port-forward` tunnels the request to `bookinfo-gateway-istio:80` in the `default` namespace.

3. **Gateway → HTTPRoute → productpage Service**

   - The Istio gateway matches `/productpage` against the `HTTPRoute` rules.
   - It routes the request to the `productpage` Service on port `9080`.

4. **productpage → other services inside cluster**

   - The `productpage` Pod calls:
     - `details` service for book metadata.
     - `reviews` service for reviews (which in turn may call `ratings`).
   - All of this communication uses Kubernetes **ClusterIP** Services and DNS (no external exposure).

5. **Response → Browser**
   - `productpage` aggregates data from `details`, `reviews`, and `ratings`, renders HTML, and sends the response back through the gateway and the port-forward tunnel to the browser.

---

### 4. Summary of Files Used Here

- `manifests/bookinfo.yaml`

  - Core Bookinfo Services, ServiceAccounts, Deployments.

- `manifests/bookinfo_versions.yaml`

  - Version-specific Services for `reviews-v1`, `reviews-v2`, `reviews-v3`, etc., so Istio can route by version later.

- `manifests/bookinfo_gateway.yaml`
  - `Gateway` (`bookinfo-gateway`) with `gatewayClassName: istio`.
  - `HTTPRoute` that exposes `/productpage` and related paths via the gateway.

With just these steps, the Bookinfo app is running in the cluster and is reachable from my laptop at `http://localhost:8080/productpage` via the Istio-managed `bookinfo-gateway-istio` service and `kubectl port-forward`.

---

## Next Steps in the Ambient Getting Started Guide

The ambient getting started flow continues with securing, visualizing, and controlling the Bookinfo traffic. These steps follow the Istio docs:

- [Deploy a sample application](https://istio.io/latest/docs/ambient/getting-started/deploy-sample-app/)
- [Secure and visualize the application](https://istio.io/latest/docs/ambient/getting-started/secure-and-visualize/)
- [Enforce authorization policies](https://istio.io/latest/docs/ambient/getting-started/enforce-auth-policies/)
- [Manage traffic](https://istio.io/latest/docs/ambient/getting-started/manage-traffic/)
- [Cleanup](https://istio.io/latest/docs/ambient/getting-started/cleanup/)

Below is a brief description of what each of the remaining steps does.

### 5. Secure and visualize the application

**What I conceptually did (based on the docs):**

- Installed Istio **ambient** data plane (ztunnel) and added the Bookinfo namespace to the mesh.
- Installed observability tools (Prometheus, Grafana, Kiali) using the provided manifests or Helm charts.

**What happens:**

- Istio deploys **ztunnel** on each node. It transparently intercepts L4 traffic for in-mesh workloads (no sidecars needed).
- All in-mesh traffic between Bookinfo services becomes **mutually authenticated (mTLS)** using identities issued by Istio.
- Metrics, logs and traces from the Bookinfo services and ambient data plane are collected:
  - Prometheus scrapes metrics.
  - Grafana visualizes dashboards.
  - Kiali shows a live service graph of Bookinfo traffic.

### 6. Enforce authorization policies

**What I conceptually did:**

- Created Istio `AuthorizationPolicy` resources to control which workloads can talk to which services (for example, which callers can access `productpage` or `details`).

**What happens:**

- Ambient data plane components (ztunnel / waypoints) enforce **authorization** at the mesh layer, using:
  - Workload identity (SPIFFE ID / service account).
  - Namespace, labels, and other selectors.
- If a request doesn’t satisfy the policy, it is **denied before it reaches the application**, so I can enforce access control without changing app code.

### 7. Manage traffic

**What I conceptually did:**

- Defined traffic management policies to control how requests flow between Bookinfo versions:
  - Split traffic between `reviews` versions (for example, send a percentage to v2).
  - Configure retries, timeouts, and possibly fault injection.
  - Use waypoint proxies for L7 (HTTP) control in ambient mode.

**What happens:**

- Ambient mesh controls **east–west** traffic:
  - At **L4**, ztunnel enforces basic connection policies.
  - At **L7**, waypoint proxies apply advanced routing:
    - Traffic shifting (canary, A/B testing).
    - Retries, timeouts, and circuit breaking.
    - Gradual rollout of new versions of `reviews` without touching app code.

### 8. Cleanup

**What I conceptually did:**

- Deleted Bookinfo resources and ambient mesh configuration following the cleanup guide.

**What happens:**

- All Bookinfo Deployments, Services, Gateways, HTTPRoutes, and policies are removed.
- Ambient data plane components for this setup are torn down and the cluster returns to a “no-mesh for Bookinfo” state.

This README now documents the full ambient getting started journey for Bookinfo: from deploying the app, exposing it through an Istio-managed gateway, securing and visualizing traffic, enforcing auth policies, managing traffic, and finally cleaning everything up.
