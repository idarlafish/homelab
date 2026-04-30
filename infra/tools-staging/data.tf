data "sops_file" "secrets" {
  source_file = "${path.root}/../secrets.sops.yaml"
}

data "hcloud_ssh_key" "main" {
  name = data.sops_file.secrets.data["clusters.tools.ssh_key_name"]
}

data "cloudflare_zone" "main" {
  filter = {
    name = data.sops_file.secrets.data["cloudflare_zone_name"]
  }
}
