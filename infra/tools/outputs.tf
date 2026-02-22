output "server_ip" {
  value       = module.server.server_ip
  description = "Public IPv4 address of the tools server"
}

output "network_id" {
  value       = module.server.network_id
  description = "ID of the private network"
}
