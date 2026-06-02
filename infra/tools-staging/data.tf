data "sops_file" "secrets" {
  source_file = "${path.root}/../secrets.sops.yaml"
}

data "cloudflare_zone" "main" {
  filter = {
    name = local.cloudflare_zone_name
  }
}
