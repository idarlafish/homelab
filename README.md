<div align="center">

# homelab

_Personal Kubernetes homelab on Hetzner. GitOps-managed._

[![Validate](https://img.shields.io/github/actions/workflow/status/idarlafish/homelab/validate.yaml?branch=main&style=flat-square&label=validate&logo=githubactions&logoColor=white)](https://github.com/idarlafish/homelab/actions/workflows/validate.yaml)&nbsp;&nbsp;
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?style=flat-square&logo=renovatebot&logoColor=white)](https://renovatebot.com)&nbsp;&nbsp;
[![Status](https://img.shields.io/badge/status-status.la.fish-blue?style=flat-square&logo=cloudflare&logoColor=white)](https://status.la.fish)&nbsp;&nbsp;
[![Size](https://img.shields.io/github/repo-size/idarlafish/homelab?style=flat-square&label=size&color=informational)](https://github.com/idarlafish/homelab)&nbsp;&nbsp;

</div>

> **Tools cluster** ~€15/mo Hetzner cax21 + volumes

> **Games cluster** ~€0 idle; ~€15/mo cx43 when playing

## Architecture

```mermaid
flowchart TD
    Browser --> CFDNS

    subgraph CF[Cloudflare]
        CFDNS[DNS · *.la.fish]
        CFTUN[Tunnel]
        CFR2[(R2 buckets<br/>tools-backups<br/>game-servers-backups<br/>fabler — tofu state)]
        CFDNS --> CFTUN
    end

    subgraph TOOLS[tools cluster · Talos · cax21]
        CFD[cloudflared]
        CFD --> PID[pocket-id<br/>OIDC SSO]
        CFD --> BL[booklore + MariaDB]
        CFD --> PL[paperless-ngx + Postgres]
        CFD --> VW[vaultwarden]
        CFD -->|"/admin"| O2V[oauth2-proxy] --> VW
        CFD --> FB[filebrowser]
        CFD --> GRF[grafana]
        CFD --> O2P[oauth2-proxy] --> PRM[prometheus + alertmanager]
        CFD --> GTS[gatus]
        ALY[alloy DaemonSet] -.->|pod logs| LK[loki]
        GRF -.-> LK

        VLR[velero + node-agent · Kopia FS backup]
        FB -. NFS .-> BL
    end

    subgraph GAMES[game-servers cluster · Talos · cx43]
        MC[minecraft]
        OTH[+ 8 others]
        VLG[velero + node-agent]
    end

    CFTUN -->|*.la.fish| CFD

    VLR .-> CFR2
    VLG .-> CFR2
```

## Stack

| Layer | Tools |
|---|---|
| **Compute & OS** | [![Talos](https://img.shields.io/badge/Talos_Linux-FF7300?style=flat-square&logoColor=white)](https://www.talos.dev/) [![Hetzner](https://img.shields.io/badge/Hetzner_Cloud-D50C2D?style=flat-square&logo=hetzner&logoColor=white)](https://www.hetzner.com/cloud) [![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)](https://kubernetes.io/) |
| **GitOps & IaC** | [![OpenTofu](https://img.shields.io/badge/OpenTofu-7B42BC?style=flat-square&logo=opentofu&logoColor=white)](https://opentofu.org/) [![Flux](https://img.shields.io/badge/FluxCD-5468FF?style=flat-square&logo=flux&logoColor=white)](https://fluxcd.io/) [![SOPS](https://img.shields.io/badge/SOPS_+_age-1E1E1E?style=flat-square&logoColor=white)](https://github.com/getsops/sops) [![Renovate](https://img.shields.io/badge/Renovate-1A1F6C?style=flat-square&logo=renovatebot&logoColor=white)](https://renovatebot.com/) |
| **Edge & Networking** | [![Tunnel](https://img.shields.io/badge/Cloudflare_Tunnel-F38020?style=flat-square&logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) [![DNS](https://img.shields.io/badge/Cloudflare_DNS-F38020?style=flat-square&logo=cloudflare&logoColor=white)](https://www.cloudflare.com/dns/) [![R2](https://img.shields.io/badge/Cloudflare_R2-F38020?style=flat-square&logo=cloudflare&logoColor=white)](https://www.cloudflare.com/developer-platform/r2/) |
| **Identity** | [![Pocket ID](https://img.shields.io/badge/Pocket_ID-1E1E1E?style=flat-square&logoColor=white)](https://pocket-id.org/) [![oauth2-proxy](https://img.shields.io/badge/oauth2--proxy-2088FF?style=flat-square&logoColor=white)](https://oauth2-proxy.github.io/oauth2-proxy/) |
| **Observability** | [![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat-square&logo=prometheus&logoColor=white)](https://prometheus.io/) [![Grafana](https://img.shields.io/badge/Grafana-F46800?style=flat-square&logo=grafana&logoColor=white)](https://grafana.com/) [![Loki](https://img.shields.io/badge/Loki-F5A623?style=flat-square&logo=grafana&logoColor=white)](https://grafana.com/oss/loki/) [![Alloy](https://img.shields.io/badge/Alloy-FF6B35?style=flat-square&logo=grafana&logoColor=white)](https://grafana.com/oss/alloy/) [![Alertmanager](https://img.shields.io/badge/Alertmanager-E6522C?style=flat-square&logo=prometheus&logoColor=white)](https://prometheus.io/docs/alerting/latest/alertmanager/) [![Gatus](https://img.shields.io/badge/Gatus-1A73E8?style=flat-square&logoColor=white)](https://gatus.io/) |
| **Backup & Storage** | [![Velero](https://img.shields.io/badge/Velero-02A9EA?style=flat-square&logoColor=white)](https://velero.io/) [![Kopia](https://img.shields.io/badge/Kopia-3E5BA9?style=flat-square&logoColor=white)](https://kopia.io/) [![csi-driver-nfs](https://img.shields.io/badge/csi--driver--nfs-326CE5?style=flat-square&logo=kubernetes&logoColor=white)](https://github.com/kubernetes-csi/csi-driver-nfs) |
| **Validation** | [![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white)](https://github.com/features/actions) [![Kustomize](https://img.shields.io/badge/Kustomize-326CE5?style=flat-square&logo=kubernetes&logoColor=white)](https://kustomize.io/) [![kubeconform](https://img.shields.io/badge/kubeconform-326CE5?style=flat-square&logo=kubernetes&logoColor=white)](https://github.com/yannh/kubeconform) [![conftest](https://img.shields.io/badge/conftest-7B42BC?style=flat-square&logoColor=white)](https://www.conftest.dev/) |

## Clusters

| Cluster | Server | State |
|---|---|---|
| `tools` | cax21 ARM | running |
| `tools-staging` | cax21 ARM | sandbox; destroyed when idle |
| `game-servers` | cx43 x86 | destroyed between play sessions |

## Apps

<details>
<summary><b>tools cluster</b></summary>

| | | Uptime |
|---|---|---|
| **pocket-id** | passkey OIDC SSO; auth provider for every other app | ![](https://status.la.fish/api/v1/endpoints/tools_pocket-id/uptimes/7d/badge.svg) |
| **booklore** + MariaDB | e-book manager | ![](https://status.la.fish/api/v1/endpoints/tools_booklore/uptimes/7d/badge.svg) |
| **paperless-ngx** + Postgres | document archive | ![](https://status.la.fish/api/v1/endpoints/tools_paperless/uptimes/7d/badge.svg) |
| **vaultwarden** | password manager; SSO via Pocket ID; `/admin` gated by oauth2-proxy | ![](https://status.la.fish/api/v1/endpoints/tools_vault/uptimes/7d/badge.svg) |
| **grafana** | dashboards (kube-prometheus-stack) | ![](https://status.la.fish/api/v1/endpoints/tools_grafana/uptimes/7d/badge.svg) |
| **prometheus** | metrics; fronted by oauth2-proxy | ![](https://status.la.fish/api/v1/endpoints/tools_prometheus/uptimes/7d/badge.svg) |
| **alertmanager** | alert routing to Telegram | |
| **loki** + **alloy** | centralized log aggregation; Alloy DaemonSet ships pod logs to Loki, Grafana queries via the Loki datasource | |
| **blackbox-exporter** | synthetic probes | |
| **gatus** | public status page at `status.la.fish` | |
| **filebrowser** | NFS bridge over booklore's PVC (rclone serve nfs + csi-driver-nfs) | |
| **velero** + node-agent | daily Kopia backups to R2 | |
| **cloudflared** | Cloudflare Tunnel | |
| **wg-easy** | VPN admin (parked at `replicas: 0`) | |

</details>

<details>
<summary><b>game-servers cluster</b></summary>

| | Notes |
|---|---|
| **minecraft, valheim, vrising, core-keeper, foundry, soulmask, enshrouded, palworld, satisfactory** | usually destroyed between play sessions |
| **grafana-alloy** | ships metrics to tools' Prometheus |
| **velero** | schedules per game |

</details>

## Validation & policy

Every push runs `.github/workflows/validate.yaml`:

- **kustomize build** + **kubeconform** — schema check on rendered manifests
- **conftest** with five Rego policies in `policy/`
- **tofu fmt -check** + **tofu validate** per infra root
- **renovate-config-validator** for `renovate.json5`

Gatus tracks the latest completed `main` run of this workflow and of `telegram-notify`'s CI in a **CI** group on [status.la.fish](https://status.la.fish), via the unauthenticated GitHub REST API (60 req/hr per IP — keep the 5m interval).

| Repo | Workflow | Status |
|---|---|---|
| **homelab** | `validate.yaml` | ![](https://status.la.fish/api/v1/endpoints/ci_homelab/uptimes/7d/badge.svg) |
| **telegram-notify** | `ci.yml` | ![](https://status.la.fish/api/v1/endpoints/ci_telegram-notify/uptimes/7d/badge.svg) |

## Infrastructure

OpenTofu state in Cloudflare R2.

| Root | Manages |
|---|---|
| `infra/tools/` | tools cluster (Talos), Cloudflare Tunnel, durable Hetzner Volumes |
| `infra/tools-staging/` | tools-staging cluster |
| `infra/game-servers/` | game-servers cluster |
| `infra/r2/` | backup buckets + lifecycle rules (account-scoped, separate state) |
| `infra/modules/tools-cluster/` | shared module for tools + tools-staging |
