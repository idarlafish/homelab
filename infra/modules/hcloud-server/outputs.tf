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

output "kube_endpoint" {
  value       = local.kubeconfig.clusters[0].cluster.server
  description = "API server endpoint URL parsed from the in-cluster kubeconfig"
}

output "kube_ca_certificate" {
  value       = local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
  description = "Base64 PEM cluster CA. Decode before passing to providers."
  sensitive   = true
}

output "kube_client_certificate" {
  value       = local.kubeconfig.users[0].user["client-certificate-data"]
  description = "Base64 PEM admin client cert. Decode before passing to providers."
  sensitive   = true
}

output "kube_client_key" {
  value       = local.kubeconfig.users[0].user["client-key-data"]
  description = "Base64 PEM admin client key. Decode before passing to providers."
  sensitive   = true
}
