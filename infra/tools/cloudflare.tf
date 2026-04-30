data "cloudflare_zone" "main" {
  filter = {
    name = data.sops_file.secrets.data["cloudflare_zone_name"]
  }
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id    = data.sops_file.secrets.data["cloudflare_account_id"]
  name          = "tools"
  config_src    = "cloudflare"
  tunnel_secret = random_id.tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = [
      {
        hostname = "auth.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://pocket-id.identity.svc.cluster.local:1411"
      },
      {
        hostname = "booklore.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://booklore.booklore.svc.cluster.local:6060"
      },
      {
        hostname = "wg-admin.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://wg-easy-http.vpn.svc.cluster.local:51821"
      },
      {
        hostname = "grafana.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80"
      },
      {
        hostname = "prometheus.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

locals {
  tunnel_hostnames = [
    "auth",
    "booklore",
    "wg-admin",
    "grafana",
    "prometheus",
  ]
}

resource "cloudflare_dns_record" "tunnel" {
  for_each = toset(local.tunnel_hostnames)

  zone_id = data.cloudflare_zone.main.zone_id
  name    = "${each.value}.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

resource "kubernetes_secret_v1" "cloudflared_token" {
  metadata {
    name      = "cloudflared-token"
    namespace = "cloudflared"
  }
  data = {
    token = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  }
  type = "Opaque"
}
