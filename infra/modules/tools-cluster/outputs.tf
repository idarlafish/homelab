output "server_ip" {
  value = module.server.server_ip
}

output "network_id" {
  value = module.server.network_id
}

output "kube_endpoint" {
  value = module.server.kube_endpoint
}

output "kube_ca_certificate" {
  value     = module.server.kube_ca_certificate
  sensitive = true
}

output "kube_client_certificate" {
  value     = module.server.kube_client_certificate
  sensitive = true
}

output "kube_client_key" {
  value     = module.server.kube_client_key
  sensitive = true
}

output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.this.id
}
