# Infra Restructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure the monorepo to support two Hetzner machines (`tools` k3s cluster, `openclaw` Docker) via a shared Terraform module, eliminating all duplication.

**Architecture:** Extract a reusable `infra/modules/hcloud-server/` Terraform module containing server, network, and base firewall. Each environment (`infra/tools/`, `infra/openclaw/`) becomes a thin caller. CI/CD workflows are renamed and scoped per machine. Duplicate `apps/vpn/kubernetes/` is removed.

**Tech Stack:** Terraform (HCL), Hetzner Cloud provider, Cloudflare R2 backend, GitHub Actions, Docker Compose, k3s

---

### Task 1: Create Terraform module — variables and outputs

**Files:**
- Create: `infra/modules/hcloud-server/variables.tf`
- Create: `infra/modules/hcloud-server/outputs.tf`

**Step 1: Create `infra/modules/hcloud-server/variables.tf`**

```hcl
variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type (e.g. cax11, cax21)"
  type        = string
  default     = "cax11"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "hel1"
}

variable "ssh_key_id" {
  description = "ID of the Hetzner uploaded SSH key"
  type        = string
}

variable "private_ip" {
  description = "Static private IP for the server within the private network"
  type        = string
}

variable "extra_firewall_ids" {
  description = "Additional environment-specific firewall IDs to attach"
  type        = list(string)
  default     = []
}

variable "cloud_init" {
  description = "Cloud-init user_data string"
  type        = string
}

variable "network_ip_range" {
  description = "IP range for the private network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_ip_range" {
  description = "IP range for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}
```

**Step 2: Create `infra/modules/hcloud-server/outputs.tf`**

```hcl
output "server_ip" {
  value       = hcloud_server.this.ipv4_address
  description = "Public IPv4 address of the server"
}

output "network_id" {
  value       = hcloud_network.this.id
  description = "ID of the private network"
}

output "server_id" {
  value       = hcloud_server.this.id
  description = "ID of the server"
}
```

**Step 3: Commit**

```bash
git add infra/modules/
git commit -m "feat(infra): add hcloud-server module scaffold (variables + outputs)"
```

---

### Task 2: Create Terraform module — network and base firewall

**Files:**
- Create: `infra/modules/hcloud-server/network.tf`
- Create: `infra/modules/hcloud-server/firewall.tf`

**Step 1: Create `infra/modules/hcloud-server/network.tf`**

```hcl
resource "hcloud_network" "this" {
  name     = "${var.name}-network"
  ip_range = var.network_ip_range
}

resource "hcloud_network_subnet" "this" {
  type         = "cloud"
  network_id   = hcloud_network.this.id
  network_zone = "eu-central"
  ip_range     = var.subnet_ip_range
}
```

**Step 2: Create `infra/modules/hcloud-server/firewall.tf`**

Base rules every machine needs (SSH in, ICMP in, outbound internet for packages/APIs):

```hcl
resource "hcloud_firewall" "base" {
  name = "${var.name}-base-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "SSH"
  }

  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0"]
    description = "ICMP ping"
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "80"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "HTTP outbound"
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "443"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "HTTPS outbound"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "53"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "DNS outbound"
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "ICMP outbound"
  }
}
```

**Step 3: Commit**

```bash
git add infra/modules/hcloud-server/network.tf infra/modules/hcloud-server/firewall.tf
git commit -m "feat(infra): add module network and base firewall resources"
```

---

### Task 3: Create Terraform module — server resource

**Files:**
- Create: `infra/modules/hcloud-server/main.tf`

**Step 1: Create `infra/modules/hcloud-server/main.tf`**

```hcl
resource "hcloud_server" "this" {
  name        = var.name
  server_type = var.server_type
  image       = "ubuntu-24.04"
  backups     = true
  ssh_keys    = [var.ssh_key_id]
  location    = var.location

  network {
    network_id = hcloud_network.this.id
    ip         = var.private_ip
  }

  firewall_ids = concat(
    [hcloud_firewall.base.id],
    var.extra_firewall_ids
  )

  user_data = var.cloud_init

  depends_on = [
    hcloud_network_subnet.this,
    hcloud_firewall.base,
  ]
}
```

**Step 2: Validate module is syntactically correct** (no provider needed for module-only validate)

```bash
cd infra/modules/hcloud-server && terraform init -backend=false 2>&1 || true
```

Expected: initialises without error (no backend needed for a module).

**Step 3: Commit**

```bash
git add infra/modules/hcloud-server/main.tf
git commit -m "feat(infra): add module server resource"
```

---

### Task 4: Create `infra/tools/` — provider, data, variables, outputs

**Files:**
- Create: `infra/tools/provider.tf`
- Create: `infra/tools/data.tf`
- Create: `infra/tools/variables.tf`
- Create: `infra/tools/outputs.tf`

**Step 1: Create `infra/tools/provider.tf`**

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
    key                         = "tools/terraform.tfstate"
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

**Step 2: Create `infra/tools/data.tf`**

```hcl
data "hcloud_ssh_key" "main" {
  name = var.ssh_key_name
}
```

**Step 3: Create `infra/tools/variables.tf`**

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
  default     = "hel1"
}
```

**Step 4: Create `infra/tools/outputs.tf`**

```hcl
output "server_ip" {
  value       = module.server.server_ip
  description = "Public IPv4 address of the tools server"
}

output "network_id" {
  value       = module.server.network_id
  description = "ID of the private network"
}
```

**Step 5: Commit**

```bash
git add infra/tools/
git commit -m "feat(infra): add tools environment scaffold"
```

---

### Task 5: Create `infra/tools/` — firewalls, cloud-init, main

**Files:**
- Create: `infra/tools/firewall.tf`
- Create: `infra/tools/cloud-init.yaml` (copy from infra/prod/)
- Create: `infra/tools/csi-config.yaml` (copy from infra/prod/)
- Create: `infra/tools/main.tf`

**Step 1: Create `infra/tools/firewall.tf`** (tools-specific rules — k8s API, web ingress, VPN, Cloudflare tunnel)

```hcl
resource "hcloud_firewall" "k8s" {
  name = "tools-k8s-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Kubernetes API"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "7844"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Cloudflare Tunnel QUIC"
  }
}

resource "hcloud_firewall" "web" {
  name = "tools-web-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTPS"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "30080"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Bot NodePort"
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s internal TCP"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s internal UDP"
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s internal ICMP"
  }
}

resource "hcloud_firewall" "vpn" {
  name = "tools-vpn-firewall"

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30000"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "WireGuard VPN"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "VPN outbound UDP (all)"
  }
}
```

**Step 2: Copy cloud-init and csi-config from prod**

These files are unchanged — exact copies from `infra/prod/`:
- `infra/tools/cloud-init.yaml` — identical to `infra/prod/cloud-init.yaml`
- `infra/tools/csi-config.yaml` — identical to `infra/prod/csi-config.yaml`

**Step 3: Create `infra/tools/main.tf`**

```hcl
module "server" {
  source = "../modules/hcloud-server"

  name       = "tools"
  server_type = "cax11"
  location   = var.hcloud_location
  ssh_key_id = data.hcloud_ssh_key.main.id
  private_ip = "10.0.1.1"
  cloud_init = file("${path.module}/cloud-init.yaml")

  extra_firewall_ids = [
    hcloud_firewall.k8s.id,
    hcloud_firewall.web.id,
    hcloud_firewall.vpn.id,
  ]
}
```

**Step 4: Validate**

```bash
cd infra/tools && terraform init \
  -backend-config="access_key=PLACEHOLDER" \
  -backend-config="secret_key=PLACEHOLDER" \
  -backend=false 2>&1 | head -20
terraform validate
```

Expected: `Success! The configuration is valid.`

**Step 5: Commit**

```bash
git add infra/tools/
git commit -m "feat(infra): add tools environment using hcloud-server module"
```

---

### Task 6: Create `infra/openclaw/`

**Files:**
- Create: `infra/openclaw/provider.tf`
- Create: `infra/openclaw/variables.tf`
- Create: `infra/openclaw/outputs.tf`
- Create: `infra/openclaw/cloud-init.yaml`
- Create: `infra/openclaw/main.tf`

**Step 1: Create `infra/openclaw/provider.tf`**

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
    key                         = "openclaw/terraform.tfstate"
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

**Step 2: Create `infra/openclaw/variables.tf`**

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
  description = "Hetzner location"
  type        = string
  default     = "hel1"
}
```

**Step 3: Create `infra/openclaw/outputs.tf`**

```hcl
output "server_ip" {
  value       = module.server.server_ip
  description = "Public IPv4 address of the openclaw server"
}
```

**Step 4: Create `infra/openclaw/cloud-init.yaml`** (Docker install, no k3s)

```yaml
#cloud-config
package_update: true
package_upgrade: true
packages:
  - ca-certificates
  - curl
runcmd:
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  - systemctl enable docker
  - systemctl start docker
```

**Step 5: Create `infra/openclaw/main.tf`**

```hcl
data "hcloud_ssh_key" "main" {
  name = var.ssh_key_name
}

module "server" {
  source = "../modules/hcloud-server"

  name       = "openclaw"
  server_type = "cax11"
  location   = var.hcloud_location
  ssh_key_id = data.hcloud_ssh_key.main.id
  private_ip = "10.0.1.2"
  cloud_init = file("${path.module}/cloud-init.yaml")
}
```

**Step 6: Validate**

```bash
cd infra/openclaw && terraform validate
```

Expected: `Success! The configuration is valid.`

**Step 7: Commit**

```bash
git add infra/openclaw/
git commit -m "feat(infra): add openclaw environment (Docker, cax11)"
```

---

### Task 7: Remove `infra/prod/` and duplicate `apps/vpn/kubernetes/`

**Step 1: Delete `infra/prod/`**

```bash
git rm -r infra/prod/
```

**Step 2: Delete `apps/vpn/kubernetes/`** (duplicates `k8s/vpn/wg-easy/`)

```bash
git rm -r apps/vpn/kubernetes/
```

**Step 3: Commit**

```bash
git commit -m "chore(infra): remove infra/prod/ (replaced by infra/tools/) and duplicate apps/vpn/kubernetes/"
```

---

### Task 8: Update GitHub Actions — deploy-tools-infra

**Files:**
- Delete: `.github/workflows/deploy-infra.yaml`
- Create: `.github/workflows/deploy-tools-infra.yaml`

**Step 1: Create `.github/workflows/deploy-tools-infra.yaml`**

```yaml
name: Deploy Tools Infrastructure

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "infra/tools/**"
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
        working-directory: infra/tools
        run: |
          terraform init \
            -backend-config="access_key=${{ secrets.S3_ACCESS_KEY }}" \
            -backend-config="secret_key=${{ secrets.S3_SECRET_KEY }}"

      - name: Terraform Plan
        id: plan
        working-directory: infra/tools
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
        working-directory: infra/tools
        if: steps.plan.outcome == 'success'
        run: terraform apply -auto-approve tfplan

      - name: Get Terraform Outputs
        working-directory: infra/tools
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
        run: helm upgrade --install hcloud-csi hcloud/hcloud-csi -n kube-system --values infra/tools/csi-config.yaml
```

**Step 2: Delete old workflow**

```bash
git rm .github/workflows/deploy-infra.yaml
```

**Step 3: Commit**

```bash
git add .github/workflows/deploy-tools-infra.yaml
git commit -m "ci: rename deploy-infra → deploy-tools-infra, scope to infra/tools/ and infra/modules/"
```

---

### Task 9: Update GitHub Actions — deploy-openclaw-infra

**Files:**
- Create: `.github/workflows/deploy-openclaw-infra.yaml`

**Step 1: Create `.github/workflows/deploy-openclaw-infra.yaml`**

```yaml
name: Deploy OpenClaw Infrastructure

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "infra/openclaw/**"
      - "infra/modules/**"

jobs:
  terraform:
    runs-on: ubuntu-latest
    outputs:
      server_ip: ${{ steps.terraform_output.outputs.SERVER_IP }}
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
        working-directory: infra/openclaw
        run: |
          terraform init \
            -backend-config="access_key=${{ secrets.S3_ACCESS_KEY }}" \
            -backend-config="secret_key=${{ secrets.S3_SECRET_KEY }}"

      - name: Terraform Plan
        id: plan
        working-directory: infra/openclaw
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
        working-directory: infra/openclaw
        if: steps.plan.outcome == 'success'
        run: terraform apply -auto-approve tfplan

      - name: Get Terraform Outputs
        working-directory: infra/openclaw
        id: terraform_output
        run: |
          echo "SERVER_IP=$(terraform output -raw server_ip)" >> $GITHUB_OUTPUT

  deploy-openclaw:
    runs-on: ubuntu-latest
    needs: terraform
    permissions:
      contents: read

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.HCLOUD_SSH_KEY }}

      - name: Wait for Docker to be ready
        uses: nick-fields/retry@v3
        with:
          timeout_seconds: 30
          max_attempts: 10
          command: ssh -o StrictHostKeyChecking=no root@${{ needs.terraform.outputs.server_ip }} "docker info"

      - name: Copy OpenClaw compose file
        run: |
          scp -o StrictHostKeyChecking=no apps/openclaw/docker-compose.yml \
            root@${{ needs.terraform.outputs.server_ip }}:/root/openclaw/docker-compose.yml

      - name: Start OpenClaw
        run: |
          ssh -o StrictHostKeyChecking=no root@${{ needs.terraform.outputs.server_ip }} \
            "cd /root/openclaw && docker compose pull && docker compose up -d"
```

**Step 2: Commit**

```bash
git add .github/workflows/deploy-openclaw-infra.yaml
git commit -m "ci: add deploy-openclaw-infra workflow"
```

---

### Task 10: Update GitHub Actions — deploy-sleepy-notify and cleanup

**Files:**
- Delete: `.github/workflows/deploy-app.yaml`
- Create: `.github/workflows/deploy-sleepy-notify.yaml`
- Delete: `.github/workflows/clenaup.yaml`
- Create: `.github/workflows/cleanup.yaml`

**Step 1: Create `.github/workflows/deploy-sleepy-notify.yaml`**

```yaml
name: Deploy Sleepy Notify

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "apps/sleepy-notify/**"

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository_owner }}/sleepy-notify
          tags: |
            type=raw,value=latest
            type=sha

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: ./apps/sleepy-notify
          file: ./apps/sleepy-notify/Dockerfile
          platforms: linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          provenance: false
          sbom: false

  rollout:
    runs-on: ubuntu-latest
    needs: build
    env:
      KUBECONFIG: /tmp/kubeconfig
    permissions:
      contents: read

    steps:
      - name: Set up SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.HCLOUD_SSH_KEY }}

      - name: Fetch kubeconfig
        run: scp -o StrictHostKeyChecking=no root@${{ vars.TOOLS_SERVER_IP }}:/root/.kube/config $KUBECONFIG

      - name: Set up kubectl
        uses: azure/setup-kubectl@v4

      - name: Rollout restart
        run: kubectl rollout restart deployment/sleepy-notify-bot -n telegram
```

**Step 2: Create `.github/workflows/cleanup.yaml`** (fixed typo from `clenaup.yaml`)

```yaml
name: Cleanup Infrastructure

on:
  workflow_dispatch:
    inputs:
      target:
        description: "Which environment to destroy (tools or openclaw)"
        required: true
        type: choice
        options:
          - tools
          - openclaw

jobs:
  cleanup:
    runs-on: ubuntu-latest
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
        working-directory: infra/${{ inputs.target }}
        run: |
          terraform init \
            -backend-config="access_key=${{ secrets.S3_ACCESS_KEY }}" \
            -backend-config="secret_key=${{ secrets.S3_SECRET_KEY }}"

      - name: Terraform Destroy
        working-directory: infra/${{ inputs.target }}
        run: terraform destroy -auto-approve
```

**Step 3: Remove old workflows and commit**

```bash
git rm .github/workflows/deploy-app.yaml .github/workflows/clenaup.yaml
git add .github/workflows/deploy-sleepy-notify.yaml .github/workflows/cleanup.yaml
git commit -m "ci: rename deploy-app → deploy-sleepy-notify (add push trigger + rollout); fix clenaup typo; cleanup supports tools|openclaw target"
```

---

### Task 11: Create `apps/openclaw/docker-compose.yml`

**Files:**
- Create: `apps/openclaw/docker-compose.yml`
- Create: `apps/openclaw/.env.example`

**Step 1: Create `apps/openclaw/docker-compose.yml`**

```yaml
services:
  openclaw:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    volumes:
      - openclaw-config:/root/.openclaw
      - openclaw-workspace:/root/openclaw/workspace
    env_file:
      - .env

volumes:
  openclaw-config:
  openclaw-workspace:
```

**Step 2: Create `apps/openclaw/.env.example`**

```
# OpenClaw configuration
# Copy to .env and fill in values — never commit .env

# AI provider (claude recommended)
OPENCLAW_AI_PROVIDER=claude
OPENCLAW_ANTHROPIC_API_KEY=

# Telegram channel (already have a bot token)
OPENCLAW_TELEGRAM_BOT_TOKEN=
```

**Step 3: Commit**

```bash
git add apps/openclaw/
git commit -m "feat(openclaw): add docker-compose and env template"
```

---

### Task 12: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Replace CLAUDE.md content**

Update to reflect two machines, correct paths (`infra/tools/`, `infra/openclaw/`), the module, and remove the nonexistent `infra/staging/` reference. Add OpenClaw section.

See exact content in implementation — follow the structure from the design doc.

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for two-machine setup"
```

---

### Task 13: Update README.md

**Files:**
- Modify: `README.md`

**Step 1: Update README.md** with two-machine overview.

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README for two-machine monorepo"
```
