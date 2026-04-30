module "server" {
  source = "../modules/hcloud-server"

  name            = "game-servers"
  server_type     = "cx43"
  location        = var.hcloud_location
  ssh_key_id      = data.hcloud_ssh_key.main.id
  ssh_private_key = data.sops_file.secrets.data["clusters.game-servers.ssh_private_key"]
  private_ip      = "10.0.1.1"
  cloud_init      = file("${path.module}/cloud-init.yaml")

  extra_firewall_ids = [
    hcloud_firewall.k8s.id,
    hcloud_firewall.servers.id,
  ]
}

module "flux_bootstrap" {
  source  = "controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes"
  version = "0.5.0"

  revision = var.bootstrap_revision

  gitops_resources = {
    instance_yaml = file("${path.root}/../../k8s/clusters/game-servers/flux-instance.yaml")
  }

  managed_resources = {
    secrets_yaml = <<-YAML
      ---
      apiVersion: v1
      kind: Secret
      metadata:
        name: flux-system
        namespace: flux-system
      type: Opaque
      stringData:
        username: git
        password: ${data.sops_file.secrets.data["flux_github_pat"]}
      ---
      apiVersion: v1
      kind: Secret
      metadata:
        name: sops-age
        namespace: flux-system
      type: Opaque
      stringData:
        age.agekey: ${var.sops_age_key}
    YAML
  }
}
