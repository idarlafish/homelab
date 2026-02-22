output "server_ip" {
  value       = hcloud_server.this.ipv4_address
  description = "Public IPv4 address of the server"
}

output "network_id" {
  value       = hcloud_network.this.id
  description = "ID of the private network"
}

output "server_id" {
  value       = hcloud_server.this.id
  description = "ID of the server"
}
