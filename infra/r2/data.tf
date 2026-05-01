data "sops_file" "secrets" {
  source_file = "${path.root}/../secrets.sops.yaml"
}
