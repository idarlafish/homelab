# Grafana + Prometheus + Alloy Monitoring

## Scope

Single Grafana instance on tools cluster monitoring both tools and game-servers clusters. Cluster health + app metrics, 24h retention, no alerting.

## Architecture

```
tools cluster (cax11)              game-servers cluster (cpx32)
├── Prometheus (scrapes local)     ├── Grafana Alloy
├── Grafana (dashboards)           │   (scrapes local metrics,
│   grafana.la.fish via CF Tunnel  │    remote-writes to tools
└── kube-prometheus-stack           │    Prometheus via CF Tunnel)
    (node-exporter,                └──
     kube-state-metrics)
```

## Components

### Tools cluster

- **kube-prometheus-stack** Helm chart in `monitoring` namespace — installs Prometheus, Grafana, node-exporter, kube-state-metrics
- **Prometheus** — 24h retention, scrapes local metrics via ServiceMonitors
- **Grafana** — Single Prometheus datasource, exposed at `grafana.la.fish` via Cloudflare Tunnel
- **Prometheus ingress** — Exposed at `prometheus.la.fish` via Cloudflare Tunnel (for Alloy remote-write from game-servers)

### Game-servers cluster

- **Grafana Alloy** Helm chart — Lightweight agent, scrapes node/kubelet/pod metrics, remote-writes to `prometheus.la.fish`
- Deployed manually via kubectl (no Flux on game-servers)

## Networking

Alloy on game-servers writes to Prometheus on tools via Cloudflare Tunnel (`prometheus.la.fish`). No firewall changes or NodePorts needed.

## FluxCD Integration (tools cluster)

- HelmRepository: `prometheus-community`, `grafana`
- HelmRelease: `kube-prometheus-stack` in `monitoring` namespace
- Cloudflared configmap updated with `grafana.la.fish` and `prometheus.la.fish` entries
- SOPS-encrypted secret for Grafana admin password

## Resource Estimates

- Tools cluster: ~300-400MB RAM
- Game-servers: ~50-80MB RAM
