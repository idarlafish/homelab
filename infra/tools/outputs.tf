output "server_ip" {
  value = module.cluster.server_ip
}

output "booklore_volume_id" {
  value = module.cluster.booklore_volume_id
}

output "pocket_id_volume_id" {
  value = hcloud_volume.pocket_id_data.id
}
