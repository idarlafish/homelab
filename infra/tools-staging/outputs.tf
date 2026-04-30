output "server_ip" {
  value       = module.server.server_ip
  description = "Public IPv4 address"
}

output "kube_endpoint" {
  value       = module.server.kube_endpoint
  description = "Kubernetes API server endpoint"
}
