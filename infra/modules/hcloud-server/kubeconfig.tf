resource "null_resource" "wait_for_kubeconfig" {
  triggers = {
    server_id = hcloud_server.this.id
  }

  provisioner "remote-exec" {
    inline = [
      "until test -s /root/.kube/config; do sleep 3; done",
    ]
    connection {
      type    = "ssh"
      user    = "root"
      host    = hcloud_server.this.ipv4_address
      agent   = true
      timeout = "5m"
    }
  }
}

data "external" "kubeconfig" {
  depends_on = [null_resource.wait_for_kubeconfig]
  program    = ["bash", "${path.module}/fetch-kubeconfig.sh"]
  query = {
    host = hcloud_server.this.ipv4_address
  }
}

locals {
  kubeconfig = yamldecode(base64decode(data.external.kubeconfig.result.kubeconfig_b64))
}
