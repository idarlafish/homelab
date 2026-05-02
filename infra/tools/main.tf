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
  cloudflare_zone_name  = data.sops_file.secrets.data["cloudflare_zone_name"]
  cloudflare_zone_id    = data.cloudflare_zone.main.zone_id

  flux_instance_yaml = file("${path.root}/../../k8s/clusters/tools/flux-instance.yaml")

  tunnel_routes = [
    { hostname = "auth.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://pocket-id.identity.svc.cluster.local:1411" },
    { hostname = "booklore.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://booklore.booklore.svc.cluster.local:6060" },
    { hostname = "wg-admin.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://wg-easy-http.vpn.svc.cluster.local:51821" },
    { hostname = "grafana.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80" },
    { hostname = "prometheus.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://oauth2-proxy-prometheus.monitoring.svc.cluster.local:4180" },
    { hostname = "status.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://gatus.uptime.svc.cluster.local:8080" },
    { hostname = "files.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://filebrowser.files.svc.cluster.local:80" },
    { hostname = "paperless.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://paperless.paperless.svc.cluster.local:8000" },
  ]
  tunnel_dns_subdomains = ["auth", "booklore", "wg-admin", "grafana", "prometheus", "status", "files", "paperless"]
}
