# Infrastructure Restructure Design — 2026-02-22

## Goal

Restructure the monorepo to cleanly support two Hetzner machines (`tools` and `openclaw`) while eliminating Terraform duplication and aligning CI/CD with the new layout. OpenClaw is a self-hosted personal AI assistant (Docker Compose) that needs its own dedicated `cax11` due to RAM constraints on the existing `tools` machine.

## Decisions

- **OpenClaw runtime**: Plain Docker + Docker Compose (not k3s). Matches how OpenClaw is built and avoids unnecessary overhead.
- **Terraform pattern**: Module-based (`infra/modules/hcloud-server/`). Each machine is a thin caller of the shared module. No workspaces.
- **State**: Both environments use the same Cloudflare R2 bucket (`fabler`) with separate state keys (`tools/terraform.tfstate`, `openclaw/terraform.tfstate`).

## Repository Structure

```
.
├── apps/
│   ├── sleepy-notify/          # Telegram bot (unchanged)
│   └── openclaw/               # NEW: docker-compose.yml + .env.example
├── infra/
│   ├── modules/
│   │   └── hcloud-server/      # NEW: reusable Hetzner server module
│   │       ├── main.tf         # hcloud_server resource
│   │       ├── network.tf      # private network + subnet
│   │       ├── firewall.tf     # base firewall (SSH, ICMP, internal)
│   │       ├── variables.tf
│   │       └── outputs.tf      # server_ip, network_id, server_id
│   ├── tools/                  # renamed from infra/prod/
│   │   ├── main.tf             # calls module + tools-specific firewalls
│   │   ├── firewall.tf         # vpn + cloudflare tunnel rules
│   │   ├── cloud-init.yaml     # k3s bootstrap
│   │   ├── csi-config.yaml
│   │   ├── provider.tf
│   │   ├── data.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── openclaw/               # NEW
│       ├── main.tf             # calls module
│       ├── cloud-init.yaml     # installs Docker + Docker Compose, no k3s
│       ├── provider.tf
│       ├── variables.tf
│       └── outputs.tf
├── k8s/                        # tools cluster manifests only
│   ├── cloudflared/
│   ├── telegram/
│   ├── vpn/
│   └── content/
│       ├── booklore/
│       └── komga/
├── .github/
│   └── workflows/
│       ├── deploy-tools-infra.yaml     # renamed; triggers on infra/tools/** + infra/modules/**
│       ├── deploy-openclaw-infra.yaml  # NEW; triggers on infra/openclaw/**
│       ├── deploy-sleepy-notify.yaml   # renamed; auto-trigger on apps/sleepy-notify/** push
│       ├── dns-update.yaml             # unchanged (reusable)
│       └── cleanup.yaml               # fixed typo; accepts target input (tools|openclaw)
├── CLAUDE.md
├── README.md
└── docs/
    └── plans/
```

**Removed:** `apps/vpn/kubernetes/` — duplicates `k8s/vpn/wg-easy/`.

## Terraform Module: `infra/modules/hcloud-server/`

The module encapsulates:
- `hcloud_server` resource (name, type, image, location, ssh_key, cloud_init, network attachment, firewall attachment)
- `hcloud_network` + `hcloud_network_subnet` (private network)
- Base `hcloud_firewall` (SSH:22, ICMP, internal cluster traffic)

**Module variables:**
- `name` — server/resource name prefix
- `server_type` — e.g. `cax11`, `cax21`
- `location` — default `hel1`
- `ssh_key_name`
- `hcloud_token`
- `private_ip` — static private IP in 10.0.x.x
- `extra_firewall_ids` — list of additional firewall IDs from the calling environment
- `cloud_init` — rendered cloud-init string

Each environment's `main.tf` creates environment-specific firewalls (e.g. VPN rules for tools, nothing extra for openclaw) and passes their IDs into `extra_firewall_ids`.

## CI/CD

| Workflow | Trigger | Action |
|---|---|---|
| `deploy-tools-infra.yaml` | push to `infra/tools/**` or `infra/modules/**` | Terraform apply in `infra/tools/`, then fetch kubeconfig + apply k8s manifests |
| `deploy-openclaw-infra.yaml` | push to `infra/openclaw/**` | Terraform apply in `infra/openclaw/`, then SSH + docker compose up |
| `deploy-sleepy-notify.yaml` | push to `apps/sleepy-notify/**` or manual | Build ARM64 image → push GHCR → kubectl rollout restart |
| `dns-update.yaml` | workflow_call | Update Cloudflare A record |
| `cleanup.yaml` | manual (input: target) | terraform destroy in selected environment |

## CLAUDE.md Updates

- Two machines documented: `tools` (k3s, cax11) and `openclaw` (Docker, cax11)
- Correct `infra/tools/` and `infra/openclaw/` paths
- Module at `infra/modules/hcloud-server/` documented
- k8s section clarifies manifests are for `tools` cluster only
- New OpenClaw section with Docker Compose dev workflow
- Remove `infra/staging/` reference (never existed)
