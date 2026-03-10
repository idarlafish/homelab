# Merge game-servers into tools

## Goal

Absorb the `game-servers` repo into `tools`. The existing Hetzner server (CPX32, AMD, fsn1) stays untouched — only the code moves.

## Directory mapping

```
game-servers/infra/*            → infra/game-servers/  (refactored to use hcloud-server module)
game-servers/apps/*/kubernetes/ → k8s/games/*/
game-servers/infra/csi-config.yaml → infra/game-servers/csi-config.yaml
game-servers/.kube/config       → .kube/game-servers   (gitignored)
game-servers/.github/workflows/ → .github/workflows/   (adapted)
```

## Excluded files

All binary data: saves, blueprints, map files, `.env`, `.idea/`, `.vscode/`, `.DS_Store`, `adminlist.txt`.

## Terraform refactor

`infra/game-servers/` uses the shared `hcloud-server` module:

```hcl
module "server" {
  source = "../modules/hcloud-server"

  name        = "game-servers"
  server_type = "cpx32"
  location    = var.hcloud_location  # default fsn1
  ssh_key_id  = data.hcloud_ssh_key.main.id
  private_ip  = "10.0.1.1"
  cloud_init  = file("${path.module}/cloud-init.yaml")

  extra_firewall_ids = [
    hcloud_firewall.servers.id,
  ]
}
```

- Base firewall (SSH, ICMP) provided by module — remove duplicates from game-specific firewall
- K8s API (6443) currently in game-servers' `common` firewall but also in module's base firewall — deduplicate
- Game port rules stay in `infra/game-servers/firewall.tf`
- State key: `game-servers/terraform.tfstate` (same R2 bucket, same key as before)

### State migration

Use `terraform state mv` to remap resources to module paths:
- `hcloud_server.main` → `module.server.hcloud_server.this`
- `hcloud_network.private_network` → `module.server.hcloud_network.this`
- `hcloud_network_subnet.private_network_subnet` → `module.server.hcloud_network_subnet.this`
- `hcloud_firewall.common` → `module.server.hcloud_firewall.base`

## CI/CD

New `deploy-game-servers-infra.yaml`:
- Trigger: push to `infra/game-servers/**` or `infra/modules/**`
- Jobs: terraform apply → deploy k8s base (kubeconfig, Helm CCM/CSI, CoreDNS patch)
- Same pattern as `deploy-tools-infra.yaml`

Add `game-servers` option to existing `cleanup.yaml`.

## K8s manifests

Games moved to `k8s/games/<game>/` with same file structure (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml or deployment.yaml).

Games: core-keeper, enshrouded, foundry, minecraft, palworld, satisfactory, valheim.

## Other updates

- `CLAUDE.md` — add game-servers section
- `.gitignore` — add `.kube/game-servers`, game data patterns
