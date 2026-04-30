data "sops_file" "secrets" {
  source_file = "${path.root}/../secrets.sops.yaml"
}

data "hcloud_ssh_key" "main" {
  name = data.sops_file.secrets.data["clusters.game-servers.ssh_key_name"]
}
