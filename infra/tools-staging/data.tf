data "sops_file" "secrets" {
  source_file = "${path.root}/../secrets.sops.yaml"
}

data "cloudflare_zone" "main" {
  filter = {
    name = data.sops_file.secrets.data["cloudflare_zone_name"]
  }
}
