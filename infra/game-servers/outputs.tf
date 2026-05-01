output "server_ip" {
  value       = module.talos.control_plane_public_ipv4_list[0]
  description = "Public IPv4 address of the game-servers node"
}
