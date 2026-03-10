# Merge game-servers into tools — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move game-servers repo code (terraform + k8s manifests) into the tools monorepo, refactoring terraform to use the shared `hcloud-server` module. No infrastructure changes — same server, same state.

**Architecture:** Create `infra/game-servers/` using the `hcloud-server` module (like tools/openclaw), copy k8s manifests to `k8s/games/<game>/`, add a deploy workflow matching the tools pattern, and migrate terraform state to the new resource paths.

**Tech Stack:** Terraform (hcloud provider 1.52.0), Cloudflare R2 state backend, GitHub Actions, k3s, Helm

---

### Task 1: Update .gitignore

**Files:**
- Modify: `.gitignore`

**Step 1: Add game-servers entries to .gitignore**

Add entries for kubeconfig and game data files. The `.kube` directory is already gitignored, so we just need game data patterns.

Append to `.gitignore`:

```
# Game server data (saves, blueprints, maps)
*.gzip
*.sbp
*.sbpcfg
*.sav
*.fwl
*.db
```

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add game data patterns to gitignore"
```

---

### Task 2: Copy K8s manifests

**Files:**
- Create: `k8s/games/core-keeper/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml)
- Create: `k8s/games/enshrouded/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml)
- Create: `k8s/games/foundry/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml)
- Create: `k8s/games/minecraft/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml)
- Create: `k8s/games/palworld/` (namespace.yaml, configmap.yaml, service.yaml, deployment.yaml, pvc.yaml)
- Create: `k8s/games/satisfactory/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml)
- Create: `k8s/games/valheim/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml)

**Step 1: Copy all kubernetes manifest directories**

Source: `~/Documents/GitHub/game-servers/apps/<game>/kubernetes/`
Destination: `k8s/games/<game>/`

Copy only yaml files. Exclude debug directories (minecraft has `debug/debug-pvc.yaml` — skip it).

```bash
for game in core-keeper enshrouded foundry minecraft palworld satisfactory valheim; do
  mkdir -p k8s/games/$game
  cp ~/Documents/GitHub/game-servers/apps/$game/kubernetes/*.yaml k8s/games/$game/
done
```

**Step 2: Verify file structure**

```bash
find k8s/games -type f -name "*.yaml" | sort
```

Expected: 4-5 yaml files per game (namespace, configmap, service, statefulset/deployment, optionally pvc).

**Step 3: Commit**

```bash
git add k8s/games/
git commit -m "feat: add game server k8s manifests from game-servers repo"
```

---

### Task 3: Create infra/game-servers terraform config

**Files:**
- Create: `infra/game-servers/provider.tf`
- Create: `infra/game-servers/main.tf`
- Create: `infra/game-servers/variables.tf`
- Create: `infra/game-servers/outputs.tf`
- Create: `infra/game-servers/data.tf`
- Create: `infra/game-servers/firewall.tf`
- Create: `infra/game-servers/cloud-init.yaml`
- Create: `infra/game-servers/csi-config.yaml`

**Step 1: Create provider.tf**

Same structure as `infra/tools/provider.tf` but with `game-servers/terraform.tfstate` key.

```hcl
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.52.0"
    }
  }
  backend "s3" {
    bucket                      = "fabler"
    key                         = "game-servers/terraform.tfstate"
    region                      = "auto"
    endpoints = {
      s3 = "https://95c5c6e1c01ea2d0c9fab69ee9e28462.r2.cloudflarestorage.com"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
```

**Step 2: Create variables.tf**

Same as `infra/tools/variables.tf` but default location is `fsn1`.

```hcl
variable "hcloud_token" {
  description = "Hetzner API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Hetzner uploaded SSH key name for provisioning"
  type        = string
}

variable "hcloud_location" {
  description = "Hetzner location (e.g. fsn1, nbg1, hel1)"
  type        = string
  default     = "fsn1"
}
```

**Step 3: Create data.tf**

```hcl
data "hcloud_ssh_key" "main" {
  name = var.ssh_key_name
}
```

**Step 4: Create main.tf**

Uses the shared `hcloud-server` module with `cpx32` and `fsn1`.

```hcl
module "server" {
  source = "../modules/hcloud-server"

  name        = "game-servers"
  server_type = "cpx32"
  location    = var.hcloud_location
  ssh_key_id  = data.hcloud_ssh_key.main.id
  private_ip  = "10.0.1.1"
  cloud_init  = file("${path.module}/cloud-init.yaml")

  extra_firewall_ids = [
    hcloud_firewall.k8s.id,
    hcloud_firewall.servers.id,
  ]
}
```

**Step 5: Create outputs.tf**

```hcl
output "server_ip" {
  value       = module.server.server_ip
  description = "Public IPv4 address of the game-servers server"
}

output "network_id" {
  value       = module.server.network_id
  description = "ID of the private network"
}
```

**Step 6: Create firewall.tf**

Split the original `common` + `servers` firewalls. The module's base firewall already covers SSH, ICMP, and limited outbound (HTTP/HTTPS/DNS/ICMP). We need:
- A `k8s` firewall for K8s API (6443) and full outbound (game servers need outbound TCP/UDP for Steam, etc.)
- A `servers` firewall for game port rules only

```hcl
resource "hcloud_firewall" "k8s" {
  name = "game-servers-k8s-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Kubernetes API"
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound TCP"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound UDP"
  }
}

resource "hcloud_firewall" "servers" {
  name = "game-servers-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "7777"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Satisfactory: Game server TCP (API)"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "7777"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Satisfactory: Game server UDP (Game)"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "18888"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Satisfactory: Game server TCP (Messaging)"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30821"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Palworld: Game server NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30921"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Palworld: Game server Query NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30637"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Enshrouded: Game server NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30456"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Valheim: Game server NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30457"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Valheim: Game server Query NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30458"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Valheim: Game server Second NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30565"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Minecraft: Game server UDP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "30565"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Minecraft: Game server TCP"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30724"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Foundry: Game server NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30668"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Core Keeper: Game server NodePort"
  }
}
```

**Step 7: Copy cloud-init.yaml**

Copy directly from `~/Documents/GitHub/game-servers/infra/cloud-init.yaml`.

```bash
cp ~/Documents/GitHub/game-servers/infra/cloud-init.yaml infra/game-servers/cloud-init.yaml
```

**Step 8: Copy csi-config.yaml**

```bash
cp ~/Documents/GitHub/game-servers/infra/csi-config.yaml infra/game-servers/csi-config.yaml
```

**Step 9: Validate terraform syntax**

```bash
cd infra/game-servers && terraform fmt -check && cd ../..
```

**Step 10: Commit**

```bash
git add infra/game-servers/
git commit -m "feat: add game-servers terraform config using hcloud-server module"
```

---

### Task 4: Create deploy workflow

**Files:**
- Create: `.github/workflows/deploy-game-servers-infra.yaml`
- Modify: `.github/workflows/cleanup.yaml`

**Step 1: Create deploy-game-servers-infra.yaml**

Based on `deploy-tools-infra.yaml`, adapted for game-servers paths.

```yaml
name: Deploy Game Servers Infrastructure

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "infra/game-servers/**"
      - "infra/modules/**"

jobs:
  terraform:
    runs-on: ubuntu-latest
    outputs:
      server_ip: ${{ steps.terraform_output.outputs.SERVER_IP }}
      network_id: ${{ steps.terraform_output.outputs.NETWORK_ID }}
    env:
      TF_VAR_hcloud_token: ${{ secrets.HCLOUD_TOKEN }}
      TF_VAR_ssh_key_name: ${{ secrets.HCLOUD_SSH_KEY_NAME }}
      AWS_ACCESS_KEY_ID: ${{ secrets.S3_ACCESS_KEY }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.S3_SECRET_KEY }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        working-directory: infra/game-servers
        run: |
          terraform init \
            -backend-config="access_key=${{ secrets.S3_ACCESS_KEY }}" \
            -backend-config="secret_key=${{ secrets.S3_SECRET_KEY }}"

      - name: Terraform Plan
        id: plan
        working-directory: infra/game-servers
        run: |
          set +e
          terraform plan -detailed-exitcode -input=false -out=tfplan
          exit_code=$?
          set -e
          if [ $exit_code -eq 2 ]; then
            echo "Pending changes detected."
            exit 0
          elif [ $exit_code -eq 0 ]; then
            echo "No changes."
            exit 0
          else
            echo "Terraform plan failed."
            exit 1
          fi

      - name: Terraform Apply
        working-directory: infra/game-servers
        if: steps.plan.outcome == 'success'
        run: terraform apply -auto-approve tfplan

      - name: Get Terraform Outputs
        working-directory: infra/game-servers
        id: terraform_output
        run: |
          echo "SERVER_IP=$(terraform output -raw server_ip)" >> $GITHUB_OUTPUT
          echo "NETWORK_ID=$(terraform output -raw network_id)" >> $GITHUB_OUTPUT

  deploy-k8s:
    runs-on: ubuntu-latest
    needs: terraform
    env:
      KUBECONFIG: /tmp/kubeconfig
    permissions:
      contents: read

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.HCLOUD_SSH_KEY }}

      - name: Fetch kubeconfig
        uses: nick-fields/retry@v3
        with:
          timeout_seconds: 30
          max_attempts: 6
          command: scp -o StrictHostKeyChecking=no root@${{ needs.terraform.outputs.server_ip }}:/root/.kube/config $KUBECONFIG

      - name: Set up Helm
        uses: azure/setup-helm@v4

      - name: Add Helm repositories
        run: |
          helm repo add hcloud https://charts.hetzner.cloud
          helm repo update

      - name: Set up kubectl
        uses: azure/setup-kubectl@v4

      - name: Fix K3s CoreDNS Bootstrap
        run: |
          kubectl wait --for=condition=Ready nodes --all --timeout=90s
          kubectl patch configmap coredns -n kube-system --type='merge' -p '{"data":{"NodeHosts":"hosts {\n  fallthrough\n}\n"}}'
          kubectl rollout status deployment/coredns -n kube-system --timeout=120s

      - name: Set up Hetzner secrets
        run: |
          kubectl create secret generic hcloud \
            --from-literal=token="${{ secrets.HCLOUD_TOKEN }}" \
            --from-literal=network="${{ needs.terraform.outputs.network_id }}" \
            --namespace kube-system \
            --dry-run=client -o yaml | kubectl apply -f -

      - name: Install Hetzner Cloud Controller Manager
        run: helm upgrade --install hccm hcloud/hcloud-cloud-controller-manager -n kube-system

      - name: Install Hetzner CSI driver
        run: helm upgrade --install hcloud-csi hcloud/hcloud-csi -n kube-system --values infra/game-servers/csi-config.yaml
```

**Step 2: Add game-servers to cleanup.yaml**

Add `game-servers` to the `options` list in the `target` input.

Change:
```yaml
        options:
          - tools
          - openclaw
```

To:
```yaml
        options:
          - tools
          - openclaw
          - game-servers
```

**Step 3: Commit**

```bash
git add .github/workflows/deploy-game-servers-infra.yaml .github/workflows/cleanup.yaml
git commit -m "ci: add game-servers deploy workflow and cleanup option"
```

---

### Task 5: Migrate terraform state

This task must be done manually with terraform CLI and real credentials. It remaps the old flat resource names to the new module-based names in the existing R2 state.

**Step 1: Init terraform in new directory**

```bash
cd infra/game-servers
terraform init \
  -backend-config="access_key=$S3_ACCESS_KEY" \
  -backend-config="secret_key=$S3_SECRET_KEY"
```

This should connect to the existing `game-servers/terraform.tfstate` in R2.

**Step 2: Verify current state**

```bash
terraform state list
```

Expected resources:
- `data.hcloud_ssh_key.main`
- `hcloud_firewall.common`
- `hcloud_firewall.servers`
- `hcloud_network.private_network`
- `hcloud_network_subnet.private_network_subnet`
- `hcloud_server.main`

**Step 3: Move resources into module namespace**

```bash
terraform state mv 'hcloud_server.main' 'module.server.hcloud_server.this'
terraform state mv 'hcloud_network.private_network' 'module.server.hcloud_network.this'
terraform state mv 'hcloud_network_subnet.private_network_subnet' 'module.server.hcloud_network_subnet.this'
terraform state mv 'hcloud_firewall.common' 'module.server.hcloud_firewall.base'
```

Note: `hcloud_firewall.servers` stays at root level (not in module), but needs renaming if it was in old state as `hcloud_firewall.servers` — check if the new config uses the same name. In our new config it's still `hcloud_firewall.servers`, so no move needed.

However, we added a new `hcloud_firewall.k8s` resource that didn't exist before. The K8s API (6443) and outbound rules were in the old `common` firewall which is now `module.server.hcloud_firewall.base`. The base module firewall has different rules (SSH, ICMP, limited outbound). So `terraform plan` will show:
- The base firewall will be updated (different rules from old `common`)
- A new `k8s` firewall will be created

**Step 4: Run terraform plan to verify**

```bash
terraform plan
```

Review the plan carefully:
- Server should show NO changes (no recreate)
- Network should show NO changes
- Firewalls may show in-place updates (rule changes) — this is expected and safe
- A new `game-servers-k8s-firewall` will be created — expected

**Step 5: Apply if plan looks safe**

```bash
terraform apply
```

Only the firewall rules change. Server, network, and data stay untouched.

---

### Task 6: Copy kubeconfig and update CLAUDE.md

**Step 1: Copy kubeconfig**

```bash
cp ~/Documents/GitHub/game-servers/.kube/config .kube/game-servers
```

This file is gitignored (`.kube` is in `.gitignore`), so it won't be committed.

**Step 2: Update CLAUDE.md**

Add a game-servers section. Insert after the OpenClaw section and before the Kubernetes section. Add:

```markdown
## Game Servers

Kubernetes-based game server infrastructure on a dedicated Hetzner CPX32 (AMD, 8 vCPU, 16GB RAM) in `fsn1`. Runs k3s with Hetzner CCM + CSI.

**Games:** Minecraft, Valheim, Palworld, Satisfactory, Enshrouded, Foundry, Core Keeper. Each runs in its own namespace with NodePort services.

K8s manifests: `k8s/games/<game>/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml or deployment.yaml).

Terraform: `infra/game-servers/` — uses shared `hcloud-server` module. State key: `game-servers/terraform.tfstate`.

When running kubectl for the game-servers cluster, use `KUBECONFIG=.kube/game-servers`.
```

Also update the repo structure diagram at the top to include game-servers paths.

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add game-servers section to CLAUDE.md"
```

---

### Task 7: Final verification

**Step 1: Verify directory structure**

```bash
find infra/game-servers -type f | sort
find k8s/games -type f | sort
ls .github/workflows/deploy-game-servers-infra.yaml
```

**Step 2: Verify no binary/data files were included**

```bash
find k8s/games -type f ! -name "*.yaml" | head -5
```

Expected: no output (only yaml files).

**Step 3: Verify terraform fmt**

```bash
cd infra/game-servers && terraform fmt -check
```

Expected: no output (all files formatted).
