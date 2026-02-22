module "server" {
  source = "../modules/hcloud-server"

  name        = "tools"
  server_type = "cax11"
  location    = var.hcloud_location
  ssh_key_id  = data.hcloud_ssh_key.main.id
  private_ip  = "10.0.1.1"
  cloud_init  = file("${path.module}/cloud-init.yaml")

  extra_firewall_ids = [
    hcloud_firewall.k8s.id,
    hcloud_firewall.web.id,
    hcloud_firewall.vpn.id,
  ]
}
