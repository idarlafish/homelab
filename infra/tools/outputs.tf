output "server_ip" {
  value = module.cluster.server_ip
}

output "network_id" {
  value = module.cluster.network_id
}

output "booklore_volume_id" {
  value = hcloud_volume.booklore_books.id
}

output "pocket_id_volume_id" {
  value = hcloud_volume.pocket_id_data.id
}
