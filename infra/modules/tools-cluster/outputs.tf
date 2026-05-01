output "server_ip" {
  value = module.talos.control_plane_public_ipv4_list[0]
}

output "kubeconfig_data" {
  value     = module.talos.kubeconfig_data
  sensitive = true
}

output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "booklore_volume_id" {
  value = hcloud_volume.booklore_books.id
}

output "pocket_id_volume_id" {
  value = hcloud_volume.pocket_id_data.id
}
