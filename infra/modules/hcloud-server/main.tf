terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "hcloud_server" "this" {
  name        = var.name
  server_type = var.server_type
  image       = "ubuntu-24.04"
  backups     = true
  ssh_keys    = [var.ssh_key_id]
  location    = var.location
  keep_disk   = true

  network {
    network_id = hcloud_network.this.id
    ip         = var.private_ip
  }

  firewall_ids = concat(
    [hcloud_firewall.base.id],
    var.extra_firewall_ids
  )

  user_data = var.cloud_init

  depends_on = [
    hcloud_network_subnet.this,
    hcloud_firewall.base,
  ]
}
