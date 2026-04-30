module "server" {
  source = "../hcloud-server"

  name             = var.name
  server_type      = var.server_type
  location         = var.location
  ssh_key_id       = var.ssh_key_id
  ssh_private_key  = var.ssh_private_key
  private_ip       = var.private_ip
  network_ip_range = var.network_ip_range
  subnet_ip_range  = var.subnet_ip_range

  extra_firewall_ids = [
    hcloud_firewall.k8s.id,
    hcloud_firewall.web.id,
    hcloud_firewall.vpn.id,
  ]
}

resource "kubernetes_secret_v1" "hcloud" {
  metadata {
    name      = "hcloud"
    namespace = "kube-system"
  }
  data = {
    network = module.server.network_id
    token   = var.hcloud_token
  }
  type = "Opaque"
}

resource "helm_release" "hccm" {
  name             = "hccm"
  repository       = "https://charts.hetzner.cloud"
  chart            = "hcloud-cloud-controller-manager"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  set = [{
    name  = "networking.enabled"
    value = "true"
  }]

  depends_on = [kubernetes_secret_v1.hcloud]
}

module "flux_bootstrap" {
  count   = var.manage_flux_bootstrap ? 1 : 0
  source  = "controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes"
  version = "0.5.0"

  revision = var.bootstrap_revision

  depends_on = [helm_release.hccm]

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
