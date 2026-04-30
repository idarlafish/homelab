output "server_ip" {
  value       = try(module.server[0].server_ip, null)
  description = "Public IPv4 address of the game-servers server. null when enable_cluster=false."
}

output "network_id" {
  value       = try(module.server[0].network_id, null)
  description = "ID of the private network. null when enable_cluster=false."
}
