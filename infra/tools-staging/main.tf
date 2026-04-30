module "cluster" {
  source = "../modules/tools-cluster"

  name             = "tools-staging"
  server_type      = "cax11"
  location         = var.hcloud_location
  private_ip       = "10.50.1.1"
  network_ip_range = "10.50.0.0/16"
  subnet_ip_range  = "10.50.1.0/24"

  ssh_key_id      = data.hcloud_ssh_key.main.id
  ssh_private_key = data.sops_file.secrets.data["clusters.tools.ssh_private_key"]

  hcloud_token       = data.sops_file.secrets.data["hcloud_token"]
  github_token       = data.sops_file.secrets.data["flux_github_pat"]
  sops_age_key       = var.sops_age_key
  bootstrap_revision = var.bootstrap_revision

  cloudflare_account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  cloudflare_api_token  = data.sops_file.secrets.data["cloudflare_api_token"]
  cloudflare_zone_name  = data.sops_file.secrets.data["cloudflare_zone_name"]
  cloudflare_zone_id    = data.cloudflare_zone.main.zone_id

  flux_instance_yaml = file("${path.root}/../../k8s/clusters/tools-staging/flux-instance.yaml")

  tunnel_routes = [
    { hostname = "auth-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://pocket-id.identity.svc.cluster.local:1411" },
    { hostname = "booklore-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://booklore.booklore.svc.cluster.local:6060" },
    { hostname = "wg-admin-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://wg-easy-http.vpn.svc.cluster.local:51821" },
    { hostname = "grafana-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80" },
    { hostname = "prometheus-staging.${data.sops_file.secrets.data["cloudflare_zone_name"]}", service = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090" },
  ]
  tunnel_dns_subdomains = ["auth-staging", "booklore-staging", "wg-admin-staging", "grafana-staging", "prometheus-staging"]
}
