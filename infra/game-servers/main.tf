module "talos" {
  source  = "hcloud-k8s/kubernetes/hcloud"
  version = "~> 3.30"

  hcloud_token = data.sops_file.secrets.data["hcloud_token"]
  cluster_name = "game-servers"

  cluster_kubeconfig_path  = "${path.root}/kubeconfig"
  cluster_talosconfig_path = "${path.root}/talosconfig"

  control_plane_nodepools = [
    {
      name     = "cp"
      type     = "cx43"
      location = var.hcloud_location
      count    = 1
    }
  ]

  worker_nodepools = []

  cluster_delete_protection      = false
  cert_manager_enabled           = false
  ingress_nginx_enabled          = false
  longhorn_enabled               = false
  kube_api_load_balancer_enabled = false

  # Don't pin Hetzner firewall to operator's current IP — mTLS is the actual
  # auth, and the IP allowlist forced a re-apply on every VPN exit rotation.
  firewall_use_current_ipv4 = false
  firewall_kube_api_source  = ["0.0.0.0/0", "::/0"]
  firewall_talos_api_source = ["0.0.0.0/0", "::/0"]

  firewall_extra_rules = [
    # Satisfactory
    { description = "Satisfactory game", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "tcp", port = "7777" },
    { description = "Satisfactory game UDP", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "7777" },
    { description = "Satisfactory messaging", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "tcp", port = "18888" },
    # NodePorts (UDP unless noted)
    { description = "Minecraft TCP NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "tcp", port = "30565" },
    { description = "Minecraft UDP NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30565" },
    { description = "Palworld game NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30821" },
    { description = "Palworld query NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30921" },
    { description = "Enshrouded NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30637" },
    { description = "Valheim game NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30456" },
    { description = "Valheim query NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30457" },
    { description = "Valheim 2nd NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30458" },
    { description = "Foundry NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30724" },
    { description = "Core Keeper NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30668" },
    { description = "V Rising game NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30876" },
    { description = "V Rising query NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30877" },
    { description = "Soulmask game NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30750" },
    { description = "Soulmask query NodePort", direction = "in", source_ips = ["0.0.0.0/0", "::/0"], protocol = "udp", port = "30751" },
  ]
}

module "flux_bootstrap" {
  source  = "controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes"
  version = "0.5.0"

  revision = var.bootstrap_revision

  depends_on = [module.talos]

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
