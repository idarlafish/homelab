output "network_id" {
  value = hcloud_network.private_network.id
  description = "ID of the private network"
}

output "server_ip" {
  value = hcloud_server.main.ipv4_address
  description = "IP address of the server"
}