module "cluster" {
  source = "../modules/tools-cluster"

  name        = "tools-staging"
  server_type = "cax21"
  location    = var.hcloud_location

  hcloud_token       = data.sops_file.secrets.data["hcloud_token"]
  github_token       = data.sops_file.secrets.data["flux_github_pat"]
  sops_age_key       = var.sops_age_key
  bootstrap_revision = var.bootstrap_revision

  cloudflare_account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  cloudflare_zone_name  = data.sops_file.secrets.data["cloudflare_zone_name"]
  cloudflare_zone_id    = data.cloudflare_zone.main.zone_id

  flux_instance_yaml = file("${path.root}/../../k8s/clusters/tools-staging/flux-instance.yaml")

  cluster_delete_protection = false

  tunnel_routes = [
    { hostname = "booklore-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://booklore.booklore.svc.cluster.local:6060" },
    { hostname = "wg-admin-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://wg-easy-http.vpn.svc.cluster.local:51821" },
    { hostname = "grafana-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80" },
    { hostname = "prometheus-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090" },
    { hostname = "paperless-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://paperless.paperless.svc.cluster.local:8000" },
    { hostname = "status-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://gatus.monitoring.svc.cluster.local:8080" },
    { hostname = "files-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://filebrowser.files.svc.cluster.local:80" },
  ]
  tunnel_dns_subdomains = ["booklore-staging", "wg-admin-staging", "grafana-staging", "prometheus-staging", "paperless-staging", "status-staging", "files-staging"]
}
