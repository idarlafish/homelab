data "sops_file" "secrets" {
  source_file = "${path.root}/../secrets.sops.yaml"
}

# tools-staging reuses the tools cluster's Hetzner SSH key (same project,
# nothing to gain from a separate key for the staging clone).
data "hcloud_ssh_key" "main" {
  name = data.sops_file.secrets.data["clusters.tools.ssh_key_name"]
}
