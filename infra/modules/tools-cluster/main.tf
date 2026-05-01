module "talos" {
  source  = "hcloud-k8s/kubernetes/hcloud"
  version = "~> 3.30"

  hcloud_token = var.hcloud_token
  cluster_name = var.name

  cluster_kubeconfig_path  = "${path.root}/kubeconfig"
  cluster_talosconfig_path = "${path.root}/talosconfig"

  control_plane_nodepools = [
    {
      name     = "cp"
      type     = var.server_type
      location = var.location
      count    = 1
    }
  ]

  worker_nodepools = []

  cluster_delete_protection      = var.cluster_delete_protection
  cert_manager_enabled           = false
  ingress_nginx_enabled          = false
  longhorn_enabled               = false
  kube_api_load_balancer_enabled = false

  # Don't pin Hetzner firewall to operator's current IP — mTLS is the actual
  # auth, and the IP allowlist forced a re-apply on every VPN exit rotation.
  firewall_use_current_ipv4 = false
  firewall_kube_api_source  = ["0.0.0.0/0", "::/0"]
  firewall_talos_api_source = ["0.0.0.0/0", "::/0"]

  firewall_extra_rules = [
    {
      description = "wg-easy WireGuard"
      direction   = "in"
      source_ips  = ["0.0.0.0/0", "::/0"]
      protocol    = "udp"
      port        = "51820"
    }
  ]
}

module "flux_bootstrap" {
  source  = "controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes"
  version = "0.5.0"

  revision = var.bootstrap_revision

  depends_on = [module.talos]

  gitops_resources = {
    instance_yaml = var.flux_instance_yaml
  }

  managed_resources = {
    secrets_yaml = <<-YAML
      ---
      apiVersion: v1
      kind: Secret
      metadata:
        name: flux-system
        namespace: flux-system
      type: Opaque
      stringData:
        username: git
        password: ${var.github_token}
      ---
      apiVersion: v1
      kind: Secret
      metadata:
        name: sops-age
        namespace: flux-system
      type: Opaque
      stringData:
        age.agekey: ${var.sops_age_key}
    YAML
  }
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id    = var.cloudflare_account_id
  name          = var.name
  config_src    = "cloudflare"
  tunnel_secret = random_id.tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = concat(
      var.tunnel_routes,
      [{ service = "http_status:404" }],
    )
  }
}

resource "cloudflare_dns_record" "tunnel" {
  for_each = toset(var.tunnel_dns_subdomains)

  zone_id = var.cloudflare_zone_id
  name    = "${each.value}.${var.cloudflare_zone_name}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

resource "kubernetes_namespace_v1" "cloudflared" {
  metadata {
    name = "cloudflared"
  }
  depends_on = [module.talos]
}

resource "kubernetes_secret_v1" "cloudflared_token" {
  metadata {
    name      = "cloudflared-token"
    namespace = kubernetes_namespace_v1.cloudflared.metadata[0].name
  }
  data = {
    token = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  }
  type = "Opaque"
}
