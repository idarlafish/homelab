output "server_ip" {
  value       = module.server.server_ip
  description = "Public IPv4 address of the tools server"
}

output "network_id" {
  value       = module.server.network_id
  description = "ID of the private network"
}

output "booklore_volume_id" {
  value       = hcloud_volume.booklore_books.id
  description = "Hetzner Volume ID backing booklore's PV (referenced from k8s PV's csi.volumeHandle)"
}
