resource "hcloud_server" "main" {
  name        = "tools"
  server_type = "cax11"
  image       = "ubuntu-24.04"
  backups     = true
  ssh_keys    = [data.hcloud_ssh_key.main.id]
  location    = var.hcloud_location
  network {
    network_id = hcloud_network.private_network.id
    ip         = "10.0.1.1"
  }
  firewall_ids = [
    hcloud_firewall.common.id,
    hcloud_firewall.telegram.id,
    hcloud_firewall.vpn.id,
  ]
  user_data   = file("${path.module}/cloud-init.yaml")
  depends_on = [
    hcloud_network_subnet.private_network_subnet,
    hcloud_firewall.common,
    hcloud_firewall.telegram,
    hcloud_firewall.vpn
  ]
}