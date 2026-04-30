module "server" {
  source = "../modules/hcloud-server"

  name             = "tools-staging"
  server_type      = "cax11"
  location         = var.hcloud_location
  ssh_key_id       = data.hcloud_ssh_key.main.id
  ssh_private_key  = data.sops_file.secrets.data["clusters.tools.ssh_private_key"]
  private_ip       = "10.50.1.1"
  network_ip_range = "10.50.0.0/16"
  subnet_ip_range  = "10.50.1.0/24"
  cloud_init       = file("${path.module}/cloud-init.yaml")

  extra_firewall_ids = [
    hcloud_firewall.k8s.id,
    hcloud_firewall.web.id,
    hcloud_firewall.vpn.id,
  ]
}

module "flux_bootstrap" {
  source  = "controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes"
  version = "0.5.0"

  revision = var.bootstrap_revision

  # Tolerate the external-cloud-provider uninitialized taint so the
  # bootstrap Job can schedule before CCM removes it.
  job = {
    tolerations = [{
      key      = "node.cloudprovider.kubernetes.io/uninitialized"
      operator = "Exists"
      effect   = "NoSchedule"
    }]
  }

  gitops_resources = {
    # Hetzner CCM installed before the FluxInstance — its pod spec
    # already tolerates the uninitialized taint, so it schedules and
    # then untaints the node, unblocking everything else.
    prerequisites = {
      charts = [{
        name       = "hccm"
        repository = "https://charts.hetzner.cloud"
        namespace  = "kube-system"
        values_yaml = yamlencode({
          networking = { enabled = true }
        })
        flux_adoption_check = {
          resource  = "deployments"
          api_group = "apps"
          name      = "hccm-hcloud-cloud-controller-manager"
          namespace = "kube-system"
        }
      }]
    }
    instance_yaml = file("${path.root}/../../k8s/clusters/tools-staging/flux-instance.yaml")
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

# hcloud Secret stays out of the bootstrap module: its `network` field is
# known-after-apply (server module output), which would force the
# bootstrap module's count predicate to be apply-time-only.
resource "kubernetes_secret_v1" "hcloud" {
  metadata {
    name      = "hcloud"
    namespace = "kube-system"
  }
  data = {
    network = module.server.network_id
    token   = data.sops_file.secrets.data["hcloud_token"]
  }
  type = "Opaque"
}
