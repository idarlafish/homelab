data "hcloud_ssh_key" "main" {
  name = var.ssh_key_name
}

module "server" {
  source = "../modules/hcloud-server"

  name        = "openclaw"
  server_type = "cax11"
  location    = var.hcloud_location
  ssh_key_id  = data.hcloud_ssh_key.main.id
  private_ip  = "10.0.1.2"
  cloud_init  = file("${path.module}/cloud-init.yaml")
}
