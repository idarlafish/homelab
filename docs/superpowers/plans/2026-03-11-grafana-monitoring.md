# Grafana Monitoring Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up Grafana + Prometheus on tools cluster with Alloy on game-servers for cross-cluster monitoring.

**Architecture:** kube-prometheus-stack Helm chart on tools cluster (Prometheus + Grafana + node-exporter + kube-state-metrics). Grafana Alloy on game-servers remote-writes to Prometheus via Cloudflare Tunnel. Both exposed via CF Tunnel (`grafana.la.fish`, `prometheus.la.fish`).

**Tech Stack:** kube-prometheus-stack Helm chart, Grafana Alloy Helm chart, FluxCD, SOPS

**Prerequisites:** FluxCD running on tools cluster. SOPS age key configured. Cloudflare Tunnel working.

---

## Chunk 1: Prometheus + Grafana on Tools Cluster

### Task 1: Add Helm repository for prometheus-community

**Files:**
- Modify: `k8s/infrastructure/helm-repos.yaml`
- Modify: `k8s/infrastructure/kustomization.yaml`

- [ ] **Step 1: Add prometheus-community HelmRepository**

Append to `k8s/infrastructure/helm-repos.yaml`:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts
```

- [ ] **Step 2: Commit**

```bash
git add k8s/infrastructure/helm-repos.yaml
git commit -m "feat: add prometheus-community Helm repository"
```

### Task 2: Create monitoring namespace and Grafana admin secret

**Files:**
- Create: `k8s/monitoring/namespace.yaml`
- Create: `k8s/monitoring/kustomization.yaml`
- Create: `k8s/secrets/monitoring-grafana-admin.yaml` (encrypted)

- [ ] **Step 1: Create monitoring namespace manifest**

Create `k8s/monitoring/namespace.yaml`:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
```

- [ ] **Step 2: Create monitoring kustomization.yaml**

Create `k8s/monitoring/kustomization.yaml`:

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
```

- [ ] **Step 3: Create Grafana admin secret**

Generate a password and create the secret YAML:

```bash
GRAFANA_PASS=$(openssl rand -base64 16)
echo "Grafana admin password: $GRAFANA_PASS"
cat > k8s/secrets/monitoring-grafana-admin.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: monitoring
stringData:
  admin-user: admin
  admin-password: $GRAFANA_PASS
type: Opaque
EOF
```

- [ ] **Step 4: Encrypt the secret with SOPS**

```bash
cd k8s/secrets
sops --encrypt --in-place monitoring-grafana-admin.yaml
cd ../..
```

- [ ] **Step 5: Add to secrets kustomization**

Edit `k8s/secrets/kustomization.yaml` — add `monitoring-grafana-admin.yaml` to the resources list.

- [ ] **Step 6: Commit**

```bash
git add k8s/monitoring/ k8s/secrets/monitoring-grafana-admin.yaml k8s/secrets/kustomization.yaml
git commit -m "feat: add monitoring namespace and Grafana admin secret"
```

### Task 3: Create kube-prometheus-stack HelmRelease

**Files:**
- Create: `k8s/infrastructure/kube-prometheus-stack.yaml`
- Modify: `k8s/infrastructure/kustomization.yaml`

- [ ] **Step 1: Create HelmRelease**

Create `k8s/infrastructure/kube-prometheus-stack.yaml`:

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: kube-prometheus-stack
  namespace: monitoring
spec:
  interval: 30m
  chart:
    spec:
      chart: kube-prometheus-stack
      version: ">=72.0.0 <73.0.0"
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
  values:
    prometheus:
      prometheusSpec:
        retention: 24h
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            memory: 512Mi
        enableRemoteWriteReceiver: true
    grafana:
      admin:
        existingSecret: grafana-admin
        userKey: admin-user
        passwordKey: admin-password
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          memory: 256Mi
    alertmanager:
      enabled: false
    nodeExporter:
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          memory: 64Mi
    kube-state-metrics:
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          memory: 64Mi
```

Key values:
- `retention: 24h` — minimal storage
- `enableRemoteWriteReceiver: true` — allows Alloy to push metrics
- `alertmanager.enabled: false` — no alerting
- `existingSecret: grafana-admin` — SOPS-managed password
- Tight resource limits for cax11

- [ ] **Step 2: Add to infrastructure kustomization**

Edit `k8s/infrastructure/kustomization.yaml` — add `kube-prometheus-stack.yaml` to the resources list.

- [ ] **Step 3: Commit**

```bash
git add k8s/infrastructure/kube-prometheus-stack.yaml k8s/infrastructure/kustomization.yaml
git commit -m "feat: add kube-prometheus-stack HelmRelease"
```

### Task 4: Add monitoring app to Flux and expose via Cloudflare Tunnel

**Files:**
- Create: `k8s/apps/monitoring.yaml`
- Modify: `k8s/apps/kustomization.yaml`
- Modify: `k8s/cloudflared/configmap.yaml`

- [ ] **Step 1: Create Flux Kustomization for monitoring**

Create `k8s/apps/monitoring.yaml`:

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: monitoring
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./k8s/monitoring
  prune: true
  wait: true
  timeout: 5m
  dependsOn:
    - name: infrastructure
    - name: secrets
```

- [ ] **Step 2: Add to apps kustomization**

Edit `k8s/apps/kustomization.yaml` — add `monitoring.yaml` to the resources list.

- [ ] **Step 3: Add Grafana and Prometheus to Cloudflare Tunnel**

Edit `k8s/cloudflared/configmap.yaml` — add before the catch-all `http_status:404` rule:

```yaml
      - hostname: grafana.la.fish
        service: http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80
        httpHostHeader: kube-prometheus-stack-grafana.monitoring.svc.cluster.local
      - hostname: prometheus.la.fish
        service: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        httpHostHeader: kube-prometheus-stack-prometheus.monitoring.svc.cluster.local
```

Note: The service names are generated by the Helm chart as `<release-name>-grafana` and `<release-name>-prometheus`. Verify after deployment with `kubectl get svc -n monitoring` and adjust if needed.

- [ ] **Step 4: Commit and push**

```bash
git add k8s/apps/monitoring.yaml k8s/apps/kustomization.yaml k8s/cloudflared/configmap.yaml
git commit -m "feat: add monitoring to Flux apps and expose via Cloudflare Tunnel"
git push
```

- [ ] **Step 5: Verify reconciliation**

```bash
flux reconcile kustomization flux-system --with-source
flux get kustomizations
flux get helmreleases -n monitoring
kubectl get pods -n monitoring
```

Expected: kube-prometheus-stack HelmRelease reconciled, all pods running in monitoring namespace.

- [ ] **Step 6: Verify Grafana accessible**

Open `https://grafana.la.fish/` — should show Grafana login. Log in with admin / the password generated in Task 2.

- [ ] **Step 7: Verify service names and fix tunnel config if needed**

```bash
kubectl get svc -n monitoring
```

If service names differ from the configmap entries, update `k8s/cloudflared/configmap.yaml` accordingly, commit and push.

## Chunk 2: Alloy on Game-Servers Cluster

### Task 5: Deploy Grafana Alloy on game-servers

**Files:**
- Create: `k8s/games/alloy/namespace.yaml`
- Create: `k8s/games/alloy/values.yaml` (reference only, used in helm install)

- [ ] **Step 1: Install Alloy via Helm on game-servers**

```bash
export KUBECONFIG=.kube/game-servers

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace alloy --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install alloy grafana/alloy -n alloy --values - <<'EOF'
alloy:
  configMap:
    content: |
      prometheus.remote_write "tools" {
        endpoint {
          url = "https://prometheus.la.fish/api/v1/write"
        }
      }

      prometheus.scrape "nodes" {
        targets         = discovery.kubernetes.nodes.targets
        forward_to      = [prometheus.remote_write.tools.receiver]
        scrape_interval = "30s"
      }

      prometheus.scrape "pods" {
        targets         = discovery.kubernetes.pods.targets
        forward_to      = [prometheus.remote_write.tools.receiver]
        scrape_interval = "30s"
      }

      prometheus.scrape "cadvisor" {
        targets         = discovery.kubernetes.nodes.targets
        forward_to      = [prometheus.remote_write.tools.receiver]
        scrape_interval = "30s"
        scheme          = "https"
        metrics_path    = "/metrics/cadvisor"
        bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        tls_config {
          insecure_skip_verify = true
        }
      }

      discovery.kubernetes "nodes" {
        role = "node"
      }

      discovery.kubernetes "pods" {
        role = "pod"
      }
  resources:
    requests:
      cpu: 25m
      memory: 64Mi
    limits:
      memory: 128Mi
EOF
```

Note: The Alloy config syntax may need adjustment based on the exact Alloy Helm chart version. Verify the chart's expected config format with `helm show values grafana/alloy` before installing.

- [ ] **Step 2: Verify Alloy is running**

```bash
kubectl get pods -n alloy
```

Expected: alloy pod Running.

- [ ] **Step 3: Verify metrics flowing to tools Prometheus**

Open `https://prometheus.la.fish/` and run a query:

```
up{cluster="game-servers"}
```

Or check targets page at `https://prometheus.la.fish/targets` for remote-write targets.

If metrics don't appear, check Alloy logs:

```bash
kubectl logs -n alloy deployment/alloy --tail=30
```

- [ ] **Step 4: Verify in Grafana**

Open `https://grafana.la.fish/`, go to Explore, query for game-servers metrics. Should see node and pod metrics from the game-servers cluster.

### Task 6: Add DNS records in Cloudflare

- [ ] **Step 1: Add DNS CNAME records**

In Cloudflare dashboard, add CNAME records for `grafana.la.fish` and `prometheus.la.fish` pointing to the tunnel (same as other `*.la.fish` records).

This is a manual step outside of git.
