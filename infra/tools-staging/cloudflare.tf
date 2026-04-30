data "cloudflare_zone" "main" {
  filter = {
    name = data.sops_file.secrets.data["cloudflare_zone_name"]
  }
}

# `staging.la.fish` is its own Cloudflare zone so Universal SSL covers
# `<host>.staging.la.fish` (free Universal SSL is one-level only;
# `*.staging.la.fish` is two levels under `la.fish` so it doesn't get
# auto-issued there). Cloudflare auto-delegates child zones inside the
# same account.
resource "cloudflare_zone" "staging" {
  account = {
    id = data.sops_file.secrets.data["cloudflare_account_id"]
  }
  name = "staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
  type = "full"
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id    = data.sops_file.secrets.data["cloudflare_account_id"]
  name          = "tools-staging"
  config_src    = "cloudflare"
  tunnel_secret = random_id.tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = [
      {
        hostname = "auth.staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://pocket-id.identity.svc.cluster.local:1411"
      },
      {
        hostname = "booklore.staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://booklore.booklore.svc.cluster.local:6060"
      },
      {
        hostname = "wg-admin.staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://wg-easy-http.vpn.svc.cluster.local:51821"
      },
      {
        hostname = "grafana.staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
        service  = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80"
      },
      {
        hostname = "prometheus.staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}"
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

  zone_id = cloudflare_zone.staging.id
  name    = "${each.value}.${cloudflare_zone.staging.name}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = data.sops_file.secrets.data["cloudflare_account_id"]
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
