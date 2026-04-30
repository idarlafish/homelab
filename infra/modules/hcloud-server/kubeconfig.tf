resource "ssh_sensitive_resource" "kubeconfig" {
  when        = "create"
  host        = hcloud_server.this.ipv4_address
  user        = "root"
  private_key = var.ssh_private_key
  timeout     = "10m"
  retry_delay = "10s"

  commands = [
    "until test -s /root/.kube/config; do sleep 3; done",
    "cat /root/.kube/config",
  ]
}

locals {
  kubeconfig = yamldecode(ssh_sensitive_resource.kubeconfig.result)
}
