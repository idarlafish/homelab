module "server" {
  source = "../modules/hcloud-server"

  name        = "game-servers"
  server_type = "cx43"
  location    = var.hcloud_location
  ssh_key_id  = data.hcloud_ssh_key.main.id
  private_ip  = "10.0.1.1"
  cloud_init  = file("${path.module}/cloud-init.yaml")

  extra_firewall_ids = [
    hcloud_firewall.k8s.id,
    hcloud_firewall.servers.id,
  ]
}
