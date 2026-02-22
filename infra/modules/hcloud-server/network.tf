resource "hcloud_network" "this" {
  name     = "${var.name}-network"
  ip_range = var.network_ip_range
}

resource "hcloud_network_subnet" "this" {
  type         = "cloud"
  network_id   = hcloud_network.this.id
  network_zone = "eu-central"
  ip_range     = var.subnet_ip_range
}
