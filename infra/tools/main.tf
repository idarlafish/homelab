locals {
  cloudflare_zone_name = "la.fish"
}

module "cluster" {
  source = "../modules/tools-cluster"

  name        = "tools"
  server_type = "cax21"
  location    = var.hcloud_location

  hcloud_token       = data.sops_file.secrets.data["hcloud_token"]
  github_token       = data.sops_file.secrets.data["flux_github_pat"]
  sops_age_key       = var.sops_age_key
  bootstrap_revision = var.bootstrap_revision

  cloudflare_account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  cloudflare_zone_name  = local.cloudflare_zone_name
  cloudflare_zone_id    = data.cloudflare_zone.main.zone_id

  flux_instance_yaml = file("${path.root}/../../k8s/clusters/tools/flux-instance.yaml")

  tunnel_routes = [
    { hostname = "auth.${local.cloudflare_zone_name}", service = "http://pocket-id.pocket-id.svc.cluster.local:1411" },
    { hostname = "booklore.${local.cloudflare_zone_name}", service = "http://booklore.booklore.svc.cluster.local:6060" },
    { hostname = "grafana.${local.cloudflare_zone_name}", service = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80" },
    { hostname = "prometheus.${local.cloudflare_zone_name}", service = "http://oauth2-proxy-prometheus.monitoring.svc.cluster.local:4180" },
    { hostname = "status.${local.cloudflare_zone_name}", service = "http://gatus.monitoring.svc.cluster.local:8080" },
    { hostname = "files.${local.cloudflare_zone_name}", service = "http://filebrowser.files.svc.cluster.local:80" },
    { hostname = "paperless.${local.cloudflare_zone_name}", service = "http://paperless.paperless.svc.cluster.local:8000" },
    { hostname = "vault.${local.cloudflare_zone_name}", path = "^/admin", service = "http://oauth2-proxy-vaultwarden.vault.svc.cluster.local:4180" },
    { hostname = "vault.${local.cloudflare_zone_name}", service = "http://vaultwarden.vault.svc.cluster.local:80" },
  ]

  manage_zone_primitives = true
}
