# Monitoring Stack Installation Guide

This directory contains scripts to install a complete monitoring stack for the `log_output` exercise, including Prometheus, Grafana, Loki, Grafana Alloy, and Kiali.

## Installation Order

Install the monitoring components in the following order:

### Step 1: Prometheus + Grafana
```bash
bash step1_grafana_prometheus.sh
```

This installs:
- Prometheus (metrics collection)
- Grafana (visualization)
- Pre-configured dashboards
- AlertManager

**Access:**
- Grafana: `kubectl -n exercises port-forward svc/prometheus-stack-grafana 3000:80` → http://localhost:3000 (admin/admin123)
- Prometheus: `kubectl -n exercises port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090` → http://localhost:9090

### Step 2: Loki + Grafana Alloy
```bash
bash step2_grafana_alloy_loki.sh
```

This installs:
- Loki (log storage)
- Grafana Alloy (log collection agent)

**Access:**
- Loki: `kubectl -n exercises port-forward svc/loki 3100:3100` → http://localhost:3100

### Step 3: Configure Grafana Data Sources
```bash
bash configure_grafana_datasources.sh
```

This configures Grafana to use:
- Loki as a log data source
- Prometheus (already auto-configured)

### Step 4: Install Kiali
```bash
bash step3_install_kiali.sh
```

This installs:
- Kiali (service mesh observability)
- ServiceMonitor and PodMonitor for Istio metrics
- Configures Kiali to use Prometheus and Grafana

**Prerequisites:**
- Istio must be installed
- Prometheus must be installed (Step 1)

**Access:**
- Kiali: `kubectl -n istio-system port-forward svc/kiali 20001:20001` → http://localhost:20001/kiali

## What Gets Configured

### Prometheus Configuration
- ServiceMonitor discovery enabled for all namespaces
- PodMonitor discovery enabled for all namespaces
- Istio metrics collection via ServiceMonitor and PodMonitor

### Kiali Configuration
- Anonymous authentication (no login required)
- Prometheus integration for metrics
- Grafana integration for dashboards
- Service mesh topology visualization

### Istio Metrics Collection
The script automatically creates:
- **ServiceMonitor**: Scrapes metrics from `istiod` service
- **PodMonitor**: Scrapes metrics from Istio proxy pods (sidecars, waypoint proxies, ztunnel)

## Troubleshooting

### Kiali shows "No metrics available"
1. Verify Prometheus is running: `kubectl get pods -n exercises -l app.kubernetes.io/name=prometheus`
2. Check ServiceMonitor/PodMonitor: `kubectl get servicemonitor,podmonitor -n exercises`
3. Verify Prometheus is scraping Istio metrics: Check Prometheus targets at http://localhost:9090/targets

### Prometheus not discovering ServiceMonitors
1. Verify Prometheus was installed with:
   - `podMonitorSelectorNilUsesHelmValues=false`
   - `serviceMonitorSelectorNilUsesHelmValues=false`
2. Check Prometheus configuration: `kubectl get prometheus -n exercises -o yaml`

### Kiali cannot connect to Prometheus
1. Verify Prometheus service name and namespace
2. Check network policies (if any)
3. Verify the Prometheus URL in Kiali config: `kubectl get configmap kiali -n istio-system -o yaml`

## Namespace

All monitoring components are installed in the `exercises` namespace by default. You can override this by setting the `NAMESPACE` environment variable:

```bash
export NAMESPACE=monitoring
bash step1_grafana_prometheus.sh
```

## k3d Compatibility

The scripts automatically detect k3d clusters and:
- Use `local-path` storage class if available
- Disable persistence if no storage class is found
- Configure components for k3d's container runtime

